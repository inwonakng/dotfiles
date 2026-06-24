import type {
  ExtensionAPI,
  ExtensionContext,
  ToolCallEvent,
} from "@earendil-works/pi-coding-agent";
import { generateUnifiedPatch } from "@earendil-works/pi-coding-agent";
import assert from "assert";
import { existsSync, readFileSync } from "fs";
import { dirname, resolve } from "path";

type AccessMode = "readonly" | "write";
type PermissionDecision = "allow" | "ask";

const ACCESS_MODES: AccessMode[] = ["readonly", "write"];
const WRITE_TOOLS = new Set(["edit", "write"]);
// this is for things we allow during readonly mode
const READONLY_BASH_ALLOWLIST = [
  "pwd",
  "uv *",
  "ls",
  "ls *",
  "rg *",
  "grep *",
  "cat *",
  "sed *",
  "head",
  "head *",
  "tail",
  "tail *",
  "wc",
  "wc *",
  "sort",
  "sort *",
  "uniq",
  "uniq *",
  "git status",
  "git status *",
  "git diff",
  "git diff *",
  "git ls-files",
  "git ls-files *",
  "stat *",
  "readlink",
  "readlink *",
];

let accessMode: AccessMode = "readonly";

function parseAccessMode(input: string): AccessMode | undefined {
  const value = input.trim().toLowerCase();
  return ACCESS_MODES.find((mode) => mode === value);
}

function modeDescription(): string {
  if (accessMode === "readonly") {
    return "Read-only work is allowed. Bash commands matching the readonly allowlist, safe find commands, web search, and custom tools may run. Other bash commands plus file edit and write tools require user approval.";
  }
  return "All available tools may run without an access-mode prompt.";
}

function normalizeCommand(command: string): string {
  return command.trim().replace(/\s+/g, " ");
}

function escapeRegExp(value: string): string {
  return value.replace(/[\\^$+?.()|[\]{}]/g, "\\$&");
}

function globToRegExp(pattern: string): RegExp {
  const parts = pattern.split("*").map(escapeRegExp);
  return new RegExp(`^${parts.join(".*")}$`);
}

function shellWords(command: string): string[] | undefined {
  const words: string[] = [];
  let current = "";
  let quote: "'" | '"' | undefined;
  let inWord = false;

  for (let index = 0; index < command.length; index++) {
    const char = command[index];
    if (quote) {
      if (char === quote) {
        quote = undefined;
      } else if (quote === '"' && char === "\\") {
        index++;
        if (index < command.length) {
          current += command[index];
        }
      } else {
        current += char;
      }
      inWord = true;
      continue;
    }

    if (char === "'" || char === '"') {
      quote = char;
      inWord = true;
      continue;
    }
    if (/\s/.test(char)) {
      if (inWord) {
        words.push(current);
        current = "";
        inWord = false;
      }
      continue;
    }
    if (char === "\\") {
      index++;
      if (index >= command.length) {
        return undefined;
      }
      current += command[index];
      inWord = true;
      continue;
    }
    current += char;
    inWord = true;
  }

  if (quote) {
    return undefined;
  }
  if (inWord) {
    words.push(current);
  }
  return words;
}

function hasUnquotedRedirection(command: string): boolean {
  let quote: "'" | '"' | undefined;
  for (let index = 0; index < command.length; index++) {
    const char = command[index];
    if (quote) {
      if (char === quote) {
        quote = undefined;
      } else if (quote === '"' && char === "\\") {
        index++;
      }
      continue;
    }
    if (char === "'" || char === '"') {
      quote = char;
      continue;
    }
    if (char === "\\") {
      index++;
      continue;
    }
    if (char === "<" || char === ">") {
      return true;
    }
  }
  return false;
}

function stripSafeReadonlyRedirections(command: string): string | undefined {
  // Sending stderr to /dev/null is common for read-only probes (find/grep/etc.)
  // and does not mutate project files. Keep all other redirection ask-gated.
  const stripped = command.replace(/(^|\s)2>\s*\/dev\/null(?=\s|$)/g, " ");
  if (hasUnquotedRedirection(stripped)) {
    return undefined;
  }
  return stripped;
}

function commandHasUnsafeShellSyntax(command: string): boolean {
  // Command substitution and background jobs can hide side effects, so keep
  // asking for those. Shell separators are handled structurally below.
  if (/[`]/.test(command) || command.includes("$(")) {
    return true;
  }
  // Allow &&, but not a bare & background operator.
  return /(^|[^&])&($|[^&])/.test(command);
}

function splitShellOperator(command: string, operator: "&&" | "||" | "|" | ";"): string[] {
  const parts: string[] = [];
  let start = 0;
  let quote: "'" | '"' | undefined;

  for (let index = 0; index < command.length; index++) {
    const char = command[index];
    if (quote) {
      if (char === quote) {
        quote = undefined;
      } else if (quote === '"' && char === "\\") {
        index++;
      }
      continue;
    }
    if (char === "'" || char === '"') {
      quote = char;
      continue;
    }
    if (char === "\\") {
      index++;
      continue;
    }
    if (command.startsWith(operator, index)) {
      parts.push(command.slice(start, index).trim());
      index += operator.length - 1;
      start = index + 1;
    }
  }

  parts.push(command.slice(start).trim());
  return parts;
}

function findExecIsReadonly(words: string[], startIndex: number): number | undefined {
  // Allow find -exec only when the invoked command itself is on the
  // read-only allowlist, e.g.:
  //   find ... -exec wc -l {} \;
  //   find ... -exec grep -n "pattern" {} \;
  // shellWords unescapes \; to ;.
  const terminatorIndex = words.indexOf(";", startIndex + 1);
  if (terminatorIndex === -1) {
    return undefined;
  }

  const invokedCommand = words.slice(startIndex + 1, terminatorIndex);
  const readonlyExecCommands = new Set([
    "cat",
    "grep",
    "head",
    "ls",
    "readlink",
    "rg",
    "stat",
    "tail",
    "wc",
  ]);
  if (
    invokedCommand.length === 0 ||
    !readonlyExecCommands.has(invokedCommand[0]) ||
    !commandWordsAllowedByReadonlyAllowlist(invokedCommand)
  ) {
    return undefined;
  }
  return terminatorIndex;
}

function findReadonlyCommandAllowed(command: string): boolean {
  const words = shellWords(command);
  if (!words || words[0] !== "find") {
    return false;
  }

  // GNU/BSD find is read-only by default, but these actions can mutate files or
  // run arbitrary commands, and f*print/f*ls variants can write output files.
  const unsafeFindPrimaries = new Set([
    "-delete",
    "-ok",
    "-okdir",
    "-fprint",
    "-fprint0",
    "-fprintf",
    "-fls",
  ]);

  for (let index = 1; index < words.length; index++) {
    const word = words[index];
    if (unsafeFindPrimaries.has(word)) {
      return false;
    }
    if (word === "-exec" || word === "-execdir") {
      const execEndIndex = findExecIsReadonly(words, index);
      if (execEndIndex === undefined) {
        return false;
      }
      index = execEndIndex;
    }
  }
  return true;
}

function commandWordsAllowedByReadonlyAllowlist(words: string[]): boolean {
  const command = words.join(" ");
  for (const pattern of READONLY_BASH_ALLOWLIST) {
    if (globToRegExp(pattern).test(command)) {
      return true;
    }
  }
  return false;
}

function xargsCommandStartIndex(words: string[]): number | undefined {
  if (words[0] !== "xargs") {
    return undefined;
  }

  // Covers common GNU/BSD xargs forms. Be conservative: if we do not
  // understand an option well enough to know whether it consumes the next token,
  // ask for approval instead of guessing where the invoked command starts.
  const shortOptionsWithRequiredArgument = [
    "-a",
    "-d",
    "-E",
    "-I",
    "-J",
    "-L",
    "-n",
    "-P",
    "-s",
  ];
  const longOptionsWithRequiredArgument = [
    "--arg-file",
    "--delimiter",
    "--eof",
    "--replace",
    "--max-lines",
    "--max-args",
    "--max-procs",
    "--max-chars",
    "--process-slot-var",
  ];
  const exactOptionsWithoutArgument = new Set([
    "-0",
    "-p",
    "-r",
    "-t",
    "-x",
    "--null",
    "--open-tty",
    "--interactive",
    "--no-run-if-empty",
    "--verbose",
    "--exit",
  ]);

  for (let index = 1; index < words.length; index++) {
    const word = words[index];
    if (word === "--") {
      return index + 1;
    }
    if (!word.startsWith("-") || word === "-") {
      return index;
    }

    const consumesRequiredArgument = longOptionsWithRequiredArgument.some(
      (option) => word === option,
    );
    if (consumesRequiredArgument) {
      index++;
      continue;
    }
    if (longOptionsWithRequiredArgument.some((option) => word.startsWith(`${option}=`))) {
      continue;
    }
    if (shortOptionsWithRequiredArgument.some((option) => word === option)) {
      index++;
      continue;
    }
    if (shortOptionsWithRequiredArgument.some((option) => word.startsWith(option) && word !== option)) {
      continue;
    }
    if (exactOptionsWithoutArgument.has(word)) {
      continue;
    }

    return undefined;
  }

  return words.length;
}

function xargsReadonlyCommandAllowed(command: string): boolean {
  const words = shellWords(command);
  if (!words || words[0] !== "xargs") {
    return false;
  }

  const commandStartIndex = xargsCommandStartIndex(words);
  if (commandStartIndex === undefined) {
    return false;
  }

  const invokedCommand = words.slice(commandStartIndex);
  if (invokedCommand.length === 0) {
    // xargs defaults to echo, which only writes to stdout.
    return true;
  }
  if (invokedCommand[0] === "xargs") {
    return false;
  }
  return commandWordsAllowedByReadonlyAllowlist(invokedCommand);
}

function simpleReadonlyCommandAllowed(command: string): boolean {
  if (command === "cd" || command.startsWith("cd ")) {
    return true;
  }
  if (findReadonlyCommandAllowed(command)) {
    return true;
  }
  if (xargsReadonlyCommandAllowed(command)) {
    return true;
  }
  if (commandWordsAllowedByReadonlyAllowlist([command])) {
    return true;
  }
  return false;
}

function readonlyCommandAllowed(command: string): boolean {
  if (command === "") {
    return false;
  }
  const strippedCommand = stripSafeReadonlyRedirections(command);
  if (strippedCommand === undefined) {
    return false;
  }
  command = strippedCommand.trim();

  if (commandHasUnsafeShellSyntax(command)) {
    return false;
  }

  const sequenceParts = splitShellOperator(command, ";");
  if (sequenceParts.length > 1) {
    return sequenceParts.every(readonlyCommandAllowed);
  }

  const orParts = splitShellOperator(command, "||");
  if (orParts.length > 1) {
    // Common read-only pattern: grep/rg may exit 1 when there are no matches.
    return (
      orParts.length === 2 &&
      orParts[1] === "true" &&
      readonlyCommandAllowed(orParts[0])
    );
  }

  const andParts = splitShellOperator(command, "&&");
  if (andParts.length > 1) {
    return andParts.every(readonlyCommandAllowed);
  }

  const pipeParts = splitShellOperator(command, "|");
  if (pipeParts.length > 1) {
    return pipeParts.every(readonlyCommandAllowed);
  }

  return simpleReadonlyCommandAllowed(command);
}

function bashPermission(input: Record<string, unknown>): PermissionDecision {
  if (typeof input.command !== "string") {
    return "ask";
  }

  const command = normalizeCommand(input.command);
  return readonlyCommandAllowed(command) ? "allow" : "ask";
}

function setStatus(ctx: ExtensionContext): void {
  ctx.ui.setStatus("pi-access-mode", `Mode: ${accessMode}`);
}

function toolSummary(event: ToolCallEvent): string {
  const input = event.input as Record<string, unknown>;
  if (event.toolName === "bash" && typeof input.command === "string") {
    return input.command;
  }
  if (
    (event.toolName === "edit" || event.toolName === "write") &&
    typeof input.path === "string"
  ) {
    return input.path;
  }
  return JSON.stringify(input);
}

function jsonPreview(value: unknown): string {
  return JSON.stringify(value, null, 2);
}

function exactEditPreview(cwd: string, input: Record<string, unknown>): string {
  const path = input.path;
  const edits = input.edits;
  if (typeof path !== "string" || !Array.isArray(edits)) {
    return jsonPreview(input);
  }

  const absolutePath = resolve(cwd, path);
  const original = readFileSync(absolutePath, "utf-8");
  const replacements: { index: number; oldText: string; newText: string }[] =
    [];
  for (const edit of edits) {
    assertEdit(edit);
    const index = original.indexOf(edit.oldText);
    const matches = original.split(edit.oldText).length - 1;
    if (matches !== 1) {
      throw new Error(
        `Cannot preview edit for ${path}: oldText matched ${matches} times.`,
      );
    }
    replacements.push({ index, oldText: edit.oldText, newText: edit.newText });
  }
  replacements.sort((left, right) => right.index - left.index);
  for (let index = 0; index < replacements.length - 1; index++) {
    const current = replacements[index];
    const next = replacements[index + 1];
    const nextEnd = next.index + next.oldText.length;
    assert(
      nextEnd <= current.index,
      `Cannot preview edit for ${path}: edits overlap.`,
    );
  }
  let nextContent = original;
  for (const replacement of replacements) {
    nextContent =
      nextContent.slice(0, replacement.index) +
      replacement.newText +
      nextContent.slice(replacement.index + replacement.oldText.length);
  }
  return generateUnifiedPatch(path, original, nextContent);
}

function writePreview(
  cwd: string,
  input: Record<string, unknown>,
): { text: string; filetype: string } {
  const path = input.path;
  const content = input.content;
  if (typeof path !== "string" || typeof content !== "string") {
    return { text: jsonPreview(input), filetype: "json" };
  }

  const absolutePath = resolve(cwd, path);
  if (!existsSync(absolutePath)) {
    return {
      text: `# New file: ${path}\n# Directory: ${dirname(absolutePath)}\n\n${content}`,
      filetype: "text",
    };
  }
  const original = readFileSync(absolutePath, "utf-8");
  return {
    text: generateUnifiedPatch(path, original, content),
    filetype: "diff",
  };
}

function assertEdit(
  value: unknown,
): asserts value is { oldText: string; newText: string } {
  assert(typeof value === "object" && value !== null, "invalid edit object");
  const edit = value as Record<string, unknown>;
  assert(typeof edit.oldText === "string", "edit.oldText must be a string");
  assert(edit.oldText.length > 0, "edit.oldText must not be empty");
  assert(typeof edit.newText === "string", "edit.newText must be a string");
}

function previewForTool(
  event: ToolCallEvent,
  ctx: ExtensionContext,
): { text: string; filetype: string } {
  const input = event.input as Record<string, unknown>;
  if (event.toolName === "bash") {
    return {
      filetype: "sh",
      text: `# cwd: ${ctx.cwd}\n# mode: ${accessMode}\n\n${typeof input.command === "string" ? input.command : jsonPreview(input)}`,
    };
  }
  if (event.toolName === "edit") {
    return { text: exactEditPreview(ctx.cwd, input), filetype: "diff" };
  }
  if (event.toolName === "write") {
    return writePreview(ctx.cwd, input);
  }
  return { text: jsonPreview(input), filetype: "json" };
}

function approvalPayload(event: ToolCallEvent, ctx: ExtensionContext): string {
  const preview = previewForTool(event, ctx);
  return JSON.stringify({
    kind: "pi_approval_preview",
    tool: event.toolName,
    mode: accessMode,
    summary: toolSummary(event),
    preview_filetype: preview.filetype,
    preview: preview.text,
  });
}

export default function accessModeExtension(pi: ExtensionAPI) {
  pi.on("session_start", (event, ctx) => {
    void event;
    setStatus(ctx);
  });

  pi.on("before_agent_start", (event) => {
    return {
      systemPrompt: `${event.systemPrompt}\n\nAccess mode: ${accessMode}. ${modeDescription()}`,
    };
  });

  pi.on("tool_call", async (event, ctx) => {
    setStatus(ctx);

    if (accessMode === "write") {
      return undefined;
    }

    const input = event.input as Record<string, unknown>;
    if (event.toolName === "bash") {
      if (bashPermission(input) === "allow") {
        return undefined;
      }
    } else if (!WRITE_TOOLS.has(event.toolName)) {
      return undefined;
    }

    if (!ctx.hasUI) {
      return {
        block: true,
        reason: `Tool "${event.toolName}" requires approval, but no UI is available.`,
      };
    }

    const confirmed = await ctx.ui.confirm(
      `Allow ${event.toolName}?`,
      approvalPayload(event, ctx),
    );
    if (!confirmed) {
      return {
        block: true,
        reason: `Tool "${event.toolName}" blocked by user.`,
      };
    }

    return undefined;
  });

  pi.registerCommand("pi-mode", {
    description: "Set access mode: /pi-mode readonly|write",
    handler: async (args, ctx) => {
      const requestedMode = parseAccessMode(args);
      if (!requestedMode) {
        ctx.ui.notify("Usage: /pi-mode readonly|write", "warning");
        setStatus(ctx);
        return;
      }

      accessMode = requestedMode;
      setStatus(ctx);
      ctx.ui.notify(`Access mode: ${accessMode}`, "info");
    },
  });
}

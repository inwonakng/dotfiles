import type {
  ExtensionAPI,
  ExtensionContext,
  ToolCallEvent,
} from "@earendil-works/pi-coding-agent";
import { generateUnifiedPatch } from "@earendil-works/pi-coding-agent";
import assert from "assert";
import { spawn, spawnSync } from "child_process";
import { existsSync, readFileSync } from "fs";
import { homedir } from "os";
import { basename, dirname, resolve } from "path";
import { fileURLToPath } from "url";

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
  "basename",
  "basename *",
  "sed *",
  "head",
  "head *",
  "nl",
  "nl *",
  "tail",
  "tail *",
  "wc",
  "wc *",
  "sort",
  "sort *",
  "uniq",
  "uniq *",
  "stat *",
  "readlink",
  "readlink *",
  "test *",
  "[ * ]",
  "[[ * ]]",
  "true",
  "false",
  "file *",
];

function parseAccessMode(input: string | undefined): AccessMode | undefined {
  if (!input) {
    return undefined;
  }
  const value = input.trim().toLowerCase();
  return ACCESS_MODES.find((mode) => mode === value);
}

let accessMode: AccessMode =
  parseAccessMode(process.env.PI_DEFER_ACCESS_MODE) ?? "readonly";
const isDeferredAgent = process.env.PI_DEFER_AGENT === "1";
const defaultIconPath = resolve(dirname(fileURLToPath(import.meta.url)), "../assets/pi-logo.png");

function alerterPath(): string | undefined {
  const configured = process.env.ALERTER;
  if (configured && existsSync(configured)) {
    return configured;
  }

  for (const candidate of ["/opt/homebrew/bin/alerter", "/usr/local/bin/alerter"]) {
    if (existsSync(candidate)) {
      return candidate;
    }
  }

  const found = spawnSync("/bin/zsh", ["-lc", "command -v alerter"], { encoding: "utf-8" });
  const path = found.stdout?.trim();
  return found.status === 0 && path ? path : undefined;
}

function notificationIconPath(): string | undefined {
  const configured = process.env.PI_NOTIFICATION_ICON;
  if (configured && existsSync(configured)) {
    return configured;
  }
  return existsSync(defaultIconPath) ? defaultIconPath : undefined;
}

function readableCwd(cwd: string, maxLength = 48): string {
  const home = homedir();
  const path = cwd === home ? "~" : cwd.startsWith(`${home}/`) ? `~/${cwd.slice(home.length + 1)}` : cwd;
  if (path.length <= maxLength) {
    return path;
  }

  const prefix = path.startsWith("~/") ? "~" : path.startsWith("/") ? "/" : "";
  const parts = path.split("/").filter(Boolean);
  const finalDir = parts.at(-1) ?? path;
  const shortenedPrefix = prefix === "/" ? "/.../" : prefix ? `${prefix}/.../` : ".../";
  const withFinalDir = `${shortenedPrefix}${finalDir}`;
  if (withFinalDir.length <= maxLength) {
    return withFinalDir;
  }

  const available = Math.max(1, maxLength - shortenedPrefix.length - 3);
  return `${shortenedPrefix}${finalDir.slice(0, available)}...`;
}

function notificationBody(pi: ExtensionAPI, ctx: ExtensionContext): string {
  return `${pi.getSessionName() || basename(ctx.cwd)}\n${readableCwd(ctx.cwd)}`;
}

function notifyPermissionRequest(pi: ExtensionAPI, ctx: ExtensionContext): void {
  const alerter = alerterPath();
  if (!alerter) {
    return;
  }

  const args = [
    "--title",
    "Requesting Permission",
    "--message",
    notificationBody(pi, ctx),
    "--group",
    "pi-coding-agent-permission",
  ];
  const iconPath = notificationIconPath();
  if (iconPath) {
    args.push("--app-icon", iconPath);
  }

  const child = spawn(alerter, args, {
    detached: true,
    stdio: "ignore",
  });
  child.on("error", () => {});
  child.unref();
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

function splitShellOperator(
  command: string,
  operator: "&&" | "||" | "|" | ";",
): string[] {
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

function findExecIsReadonly(
  words: string[],
  startIndex: number,
): number | undefined {
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
    "basename",
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
    if (
      longOptionsWithRequiredArgument.some((option) =>
        word.startsWith(`${option}=`),
      )
    ) {
      continue;
    }
    if (shortOptionsWithRequiredArgument.some((option) => word === option)) {
      index++;
      continue;
    }
    if (
      shortOptionsWithRequiredArgument.some(
        (option) => word.startsWith(option) && word !== option,
      )
    ) {
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

function awkReadonlyCommandAllowed(command: string): boolean {
  const words = shellWords(command);
  if (!words || words[0] !== "awk") {
    return false;
  }

  let programIndex: number | undefined;
  for (let index = 1; index < words.length; index++) {
    const word = words[index];
    if (word === "--") {
      programIndex = index + 1;
      break;
    }
    if (word === "-F" || word === "-v") {
      index++;
      if (index >= words.length) {
        return false;
      }
      continue;
    }
    if (word.startsWith("-F") && word !== "-F") {
      continue;
    }
    if (word.startsWith("-")) {
      // This intentionally ask-gates -f/--file and extension/loading options:
      // the external awk program could contain writes or system calls.
      return false;
    }
    programIndex = index;
    break;
  }

  if (programIndex === undefined || programIndex >= words.length) {
    return false;
  }

  const program = words[programIndex];
  if (/\bsystem\s*\(/.test(program)) {
    return false;
  }
  // Awk can run shell commands with pipe redirections, e.g. print | "cmd".
  if (/(^|[^|])\|($|[^|])/.test(program)) {
    return false;
  }
  // Ask-gate output redirections in print/printf statements, while still
  // allowing comparison operators such as NR>=1285 in the user's range probes.
  if (/\bprint(?:f)?\b.*(^|[^<>!])>{1,2}($|[^=])/.test(program)) {
    return false;
  }

  return true;
}

function gitSubcommandStartIndex(words: string[]): number | undefined {
  if (words[0] !== "git") {
    return undefined;
  }

  // Parse the small set of global git options we want to support in readonly
  // mode. In particular, this allows common probes such as:
  //   git -C /path/to/repo log -1 --oneline
  // Unknown global options ask for approval instead of guessing where the
  // subcommand starts.
  const globalOptionsWithRequiredArgument = new Set(["-C"]);
  const globalOptionsWithoutArgument = new Set(["--no-pager"]);

  for (let index = 1; index < words.length; index++) {
    const word = words[index];
    if (word === "--") {
      return undefined;
    }
    if (!word.startsWith("-") || word === "-") {
      return index;
    }
    if (globalOptionsWithRequiredArgument.has(word)) {
      index++;
      if (index >= words.length) {
        return undefined;
      }
      continue;
    }
    if (globalOptionsWithoutArgument.has(word)) {
      continue;
    }
    return undefined;
  }

  return undefined;
}

function gitReadonlyCommandAllowed(command: string): boolean {
  const words = shellWords(command);
  if (!words || words[0] !== "git") {
    return false;
  }

  const commandStartIndex = gitSubcommandStartIndex(words);
  if (commandStartIndex === undefined) {
    return false;
  }

  const subcommand = words[commandStartIndex];
  const readonlySubcommands = new Set(["diff", "log", "ls-files", "status"]);
  if (!readonlySubcommands.has(subcommand)) {
    return false;
  }

  // Keep command-level output/execution escape hatches ask-gated. Shell-level
  // redirection is handled separately by stripSafeReadonlyRedirections().
  const unsafeOptions = new Set(["--ext-diff", "--external-diff", "--output"]);
  for (const word of words.slice(commandStartIndex + 1)) {
    if (unsafeOptions.has(word) || word.startsWith("--output=")) {
      return false;
    }
  }

  return true;
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
  if (awkReadonlyCommandAllowed(command)) {
    return true;
  }
  if (gitReadonlyCommandAllowed(command)) {
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

  const andParts = splitShellOperator(command, "&&");
  if (andParts.length > 1) {
    return andParts.every(readonlyCommandAllowed);
  }

  const orParts = splitShellOperator(command, "||");
  if (orParts.length > 1) {
    // Common read-only pattern: grep/rg/find may exit non-zero when there are
    // no matches. Handle this after && splitting so commands like
    // `find ... || true && rg ...` are checked as separate read-only clauses.
    return (
      orParts.length === 2 &&
      orParts[1] === "true" &&
      readonlyCommandAllowed(orParts[0])
    );
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
    const deferredNote =
      isDeferredAgent && accessMode === "readonly"
        ? " This is a deferred subagent: actions requiring approval are blocked instead of asking the user. If blocked, stop and report BLOCKED with the exact action that required write access."
        : "";
    return {
      systemPrompt: `${event.systemPrompt}\n\nAccess mode: ${accessMode}. ${modeDescription()}${deferredNote}`,
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

    if (isDeferredAgent) {
      return {
        block: true,
        reason: `Tool "${event.toolName}" requires approval, but this deferred agent is running in readonly mode.`,
      };
    }

    if (!ctx.hasUI) {
      return {
        block: true,
        reason: `Tool "${event.toolName}" requires approval, but no UI is available.`,
      };
    }

    notifyPermissionRequest(pi, ctx);

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

import {
  generateUnifiedPatch,
  type ExtensionAPI,
  type ExtensionContext,
  type ToolCallEvent,
} from "@earendil-works/pi-coding-agent";
import assert from "node:assert";
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { getAccessMode, parseAccessMode, setAccessMode } from "./shared/access-state";

const MUTATING_FILE_COMMANDS =
  "rm|rmdir|mv|cp|mkdir|touch|chmod|chown|chgrp|ln|tee|truncate|dd|shred";
const COMMAND_START = String.raw`(?:^|[;&|]\s*)(?:\w+=\S+\s+)*`;
const READONLY_TOOLS = new Set(["read", "grep", "find", "ls", "web_search", "web_fetch"]);
const READONLY_WORKSPACE_ACTIONS = new Set(["status", "list"]);
const READONLY_SPAWN_CONTROL_ACTIONS = new Set(["list", "status", "join", "join_all"]);

const READONLY_BASH_DENYLIST: Array<{ pattern: RegExp; reason: string }> = [
  {
    pattern: commandPattern(MUTATING_FILE_COMMANDS),
    reason: "file mutation command",
  },
  {
    pattern: commandPattern("vim?|nvim|nano|emacs|code|subl"),
    reason: "interactive editor can modify files",
  },
  {
    pattern: /\bfind\b[^;&|]*\s-delete\b/i,
    reason: "find -delete mutates files",
  },
  {
    pattern: new RegExp(
      String.raw`\bfind\b[^;&|]*\s-exec(?:dir)?\s+(?:${MUTATING_FILE_COMMANDS}|bash|sh|zsh|fish|osascript|python|python3|node|ruby|perl)\b`,
      "i",
    ),
    reason: "find -exec mutation command",
  },
  {
    pattern: new RegExp(
      String.raw`\bxargs\b(?:\s+(?:-[A-Za-z0-9{}]+|--[A-Za-z0-9-]+(?:=\S+)?))*\s+(?:${MUTATING_FILE_COMMANDS}|bash|sh|zsh|fish|osascript|python|python3|node|ruby|perl)\b`,
      "i",
    ),
    reason: "xargs mutation command",
  },
  { pattern: /\bsed\b[^;&|]*\s-i(?:\s|$)/i, reason: "in-place sed edit" },
  { pattern: /\bperl\b[^;&|]*\s-p?i(?:\s|$)/i, reason: "in-place perl edit" },
  {
    pattern: new RegExp(
      String.raw`${COMMAND_START}git\s+(?:-C\s+(?:"[^"]+"|'[^']+'|\S+)\s+|--no-pager\s+)*(?:add|am|apply|bisect|branch|checkout|cherry-pick|clean|clone|commit|fetch|format-patch|init|merge|mv|pull|push|rebase|reset|restore|revert|rm|stash|submodule|switch|tag|worktree)\b`,
      "i",
    ),
    reason: "mutating git command",
  },
  {
    pattern: /\bgit\b[^;&|]*\s--(?:output|ext-diff|external-diff)(?:=|\s|$)/i,
    reason: "git option can write files or run external commands",
  },
  {
    pattern:
      /(?:^|[;&|]\s*)(?:npm|yarn|pnpm|bun)\s+(?:install|uninstall|update|add|remove|ci|link|publish|version|upgrade)\b/i,
    reason: "package manager mutation",
  },
  {
    pattern: /(?:^|[;&|]\s*)(?:pip|pipx|uv(?:\s+pip)?)\s+(?:install|uninstall|sync|add|remove|lock)\b/i,
    reason: "Python environment mutation",
  },
  {
    pattern:
      /(?:^|[;&|]\s*)(?:brew|apt|apt-get|dnf|yum|pacman)\s+(?:install|uninstall|remove|purge|update|upgrade|add)\b/i,
    reason: "system package mutation",
  },
  {
    pattern: /(?:^|[;&|]\s*)(?:curl|wget)\b[^;&|]*(?:\s-o\s|\s-O(?:\s|$)|--output(?:=|\s)|--output-document(?:=|\s))/i,
    reason: "download command writes to a file",
  },
  {
    pattern: /(?:^|[;&|]\s*)tar\b[^;&|]*\s-(?:[^\s-]*x|-[^;&|]*(?:extract|get))/i,
    reason: "archive extraction writes files",
  },
  {
    pattern: commandPattern("unzip|gunzip"),
    reason: "archive extraction writes files",
  },
  {
    pattern: commandPattern("sudo|su|kill|pkill|killall|reboot|shutdown"),
    reason: "privileged or process-control command",
  },
  {
    pattern:
      /(?:^|[;&|]\s*)(?:systemctl|service|launchctl)\s+(?:start|stop|restart|enable|disable|load|unload|kickstart|bootout)\b/i,
    reason: "service mutation",
  },
  {
    pattern: /(?:^|[;&|]\s*)(?:bash|sh|zsh|fish|osascript|python|python3|node|ruby|perl)\s+(?:-c|-e)\b/i,
    reason: "inline interpreter can hide side effects",
  },
];

function commandPattern(commands: string): RegExp {
  return new RegExp(`${COMMAND_START}(?:${commands})\\b`, "i");
}

function normalizeCommand(command: string): string {
  return command.trim().replace(/\s+/g, " ");
}

function fileDescriptorDuplicationEnd(command: string, index: number): number | undefined {
  const match = command.slice(index).match(/^[<>]&\s*(?:\d+|-)(?=$|[\s;&|()<>])/);
  return match ? index + match[0].length : undefined;
}

function hasUnquotedShellWriteSyntax(command: string): boolean {
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
      const duplicationEnd = fileDescriptorDuplicationEnd(command, index);
      if (duplicationEnd !== undefined) {
        index = duplicationEnd - 1;
        continue;
      }
      return true;
    }
    if (char === "&" && command[index - 1] !== "&" && command[index + 1] !== "&") {
      return true;
    }
  }
  return false;
}

function maskShellQuotedContent(command: string): string {
  let output = "";
  let quote: "'" | '"' | undefined;
  for (let index = 0; index < command.length; index++) {
    const char = command[index];
    if (quote) {
      if (char === quote) {
        quote = undefined;
        output += char;
      } else if (quote === '"' && char === "\\") {
        output += " ";
        index++;
        if (index < command.length) {
          output += " ";
        }
      } else {
        output += " ";
      }
      continue;
    }
    if (char === "'" || char === '"') {
      quote = char;
      output += char;
      continue;
    }
    if (char === "\\") {
      output += " ";
      index++;
      if (index < command.length) {
        output += " ";
      }
      continue;
    }
    output += char;
  }
  return output;
}

export function readonlyBashBlockReason(command: string): string | undefined {
  const normalized = normalizeCommand(command);
  if (!normalized) {
    return "empty command";
  }

  // Sending stderr to /dev/null is common for read-only probes and does not
  // mutate project files. Keep other redirections and background jobs blocked.
  const withoutBenignStderr = normalized.replace(/(^|\s)2>\s*\/dev\/null(?=\s|$)/g, " ");
  if (hasUnquotedShellWriteSyntax(withoutBenignStderr)) {
    return "shell redirection or background execution";
  }
  if (/[`]/.test(normalized) || normalized.includes("$(")) {
    return "command substitution can hide side effects";
  }

  const denylistCommand = maskShellQuotedContent(normalized);
  const blocked = READONLY_BASH_DENYLIST.find(({ pattern }) => pattern.test(denylistCommand));
  return blocked?.reason;
}

function jsonPreview(value: unknown): string {
  return JSON.stringify(value, null, 2) ?? String(value);
}

function assertEdit(value: unknown): asserts value is { oldText: string; newText: string } {
  assert(typeof value === "object" && value !== null, "invalid edit object");
  const edit = value as Record<string, unknown>;
  assert(typeof edit.oldText === "string", "edit.oldText must be a string");
  assert(edit.oldText.length > 0, "edit.oldText must not be empty");
  assert(typeof edit.newText === "string", "edit.newText must be a string");
}

function exactEditPreview(cwd: string, input: Record<string, unknown>): string {
  const path = input.path;
  const edits = input.edits;
  if (typeof path !== "string" || !Array.isArray(edits)) {
    return jsonPreview(input);
  }

  const original = readFileSync(resolve(cwd, path), "utf-8");
  const replacements: Array<{ index: number; oldText: string; newText: string }> = [];
  for (const edit of edits) {
    assertEdit(edit);
    const index = original.indexOf(edit.oldText);
    const matches = original.split(edit.oldText).length - 1;
    assert(matches === 1, `Cannot preview edit for ${path}: oldText matched ${matches} times.`);
    replacements.push({ index, oldText: edit.oldText, newText: edit.newText });
  }

  replacements.sort((left, right) => right.index - left.index);
  for (let index = 0; index < replacements.length - 1; index++) {
    const current = replacements[index];
    const next = replacements[index + 1];
    assert(next.index + next.oldText.length <= current.index, `Cannot preview edit for ${path}: edits overlap.`);
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

function writePreview(cwd: string, input: Record<string, unknown>): { text: string; filetype: string } {
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
  return { text: generateUnifiedPatch(path, original, content), filetype: "diff" };
}

function previewForTool(event: ToolCallEvent, ctx: ExtensionContext): { text: string; filetype: string } {
  const input = event.input as Record<string, unknown>;
  if (event.toolName === "bash") {
    const command = typeof input.command === "string" ? input.command : jsonPreview(input);
    return {
      filetype: "sh",
      text: `# cwd: ${ctx.cwd}\n# mode: ${getAccessMode()}\n\n${command}`,
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
  const input = event.input as Record<string, unknown>;
  const summary = event.toolName === "bash" && typeof input.command === "string"
    ? input.command
    : typeof input.path === "string"
      ? input.path
      : JSON.stringify(input);
  return JSON.stringify({
    kind: "pi_approval_preview",
    tool: event.toolName,
    mode: getAccessMode(),
    summary,
    preview_filetype: preview.filetype,
    preview: preview.text,
  });
}

function workspaceManagesApproval(input: Record<string, unknown>): boolean {
  return input.action === "integrate" || input.action === "discard";
}

function readonlyToolBlockReason(
  toolName: string,
  input: Record<string, unknown>,
): string | undefined {
  if (READONLY_TOOLS.has(toolName)) {
    return undefined;
  }

  if (toolName === "bash") {
    if (typeof input.command !== "string") {
      return "bash requires a command that can be classified as read-only";
    }
    const reason = readonlyBashBlockReason(input.command);
    return reason ? `bash command is not read-only: ${reason}` : undefined;
  }

  if (toolName === "workspace") {
    return typeof input.action === "string" && READONLY_WORKSPACE_ACTIONS.has(input.action)
      ? undefined
      : "workspace action is not whitelisted as read-only";
  }

  if (toolName === "spawn") {
    if (input.accessMode !== "readonly") {
      return "spawn requires explicit accessMode=readonly";
    }
    return input.isolation === undefined || input.isolation === "none"
      ? undefined
      : "spawn worktree isolation is not read-only";
  }

  if (toolName === "spawn_control") {
    return typeof input.action === "string" && READONLY_SPAWN_CONTROL_ACTIONS.has(input.action)
      ? undefined
      : "spawn_control action is not whitelisted as read-only";
  }

  return `tool "${toolName}" is not whitelisted as read-only`;
}

function setStatus(ctx: ExtensionContext): void {
  ctx.ui.setStatus("pi-access-mode", `Mode: ${getAccessMode()}`);
}

export default function accessModeExtension(pi: ExtensionAPI) {
  pi.on("session_start", (event, ctx) => {
    void event;
    setStatus(ctx);
  });

  pi.on("tool_call", async (event, ctx) => {
    setStatus(ctx);

    const mode = getAccessMode();
    if (mode === "edit") {
      return undefined;
    }

    const input = event.input as Record<string, unknown>;
    if (event.toolName === "workspace" && workspaceManagesApproval(input)) {
      return undefined;
    }

    const reason = readonlyToolBlockReason(event.toolName, input);
    if (!reason) {
      return undefined;
    }

    if (
      event.toolName === "spawn"
      && (input.accessMode === "edit" || input.isolation === "worktree")
    ) {
      return {
        block: true,
        reason: "Spawning edit-mode or isolated subagents requires parent access mode edit. Run /pi-mode edit before delegating edit work.",
      };
    }

    if (mode === "readonly") {
      return {
        block: true,
        reason: `Tool "${event.toolName}" is blocked in readonly mode (${reason}).`,
      };
    }

    if (process.env.PI_SPAWN_AGENT === "1" || !ctx.hasUI) {
      const context = process.env.PI_SPAWN_AGENT === "1"
        ? "spawned subagents cannot request approval"
        : "no UI is available";
      return {
        block: true,
        reason: `Tool "${event.toolName}" requires approval (${reason}), but ${context}.`,
      };
    }

    const confirmed = await ctx.ui.confirm(
      `Allow ${event.toolName}?`,
      approvalPayload(event, ctx),
      { signal: ctx.signal },
    );
    return confirmed
      ? undefined
      : { block: true, reason: `Tool "${event.toolName}" blocked by user.` };
  });

  pi.registerCommand("pi-mode", {
    description: "Set access mode: /pi-mode readonly|ask|edit",
    handler: async (args, ctx) => {
      const requestedMode = parseAccessMode(args);
      if (!requestedMode) {
        ctx.ui.notify("Usage: /pi-mode readonly|ask|edit", "warning");
        setStatus(ctx);
        return;
      }

      setAccessMode(requestedMode);
      setStatus(ctx);
      ctx.ui.notify(`Access mode: ${getAccessMode()}`, "info");
    },
  });
}

import type {
  ExtensionAPI,
  ExtensionContext,
  ToolCallEvent,
} from "@earendil-works/pi-coding-agent";
import { generateUnifiedPatch } from "@earendil-works/pi-coding-agent";
import assert from "node:assert";
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { notificationsEnabled, sendAlerterNotification } from "./shared/notifications";

type AccessMode = "readonly" | "write";
type PermissionDecision = "allow" | "ask";

const ACCESS_MODES: AccessMode[] = ["readonly", "write"];
const WRITE_TOOLS = new Set(["edit", "write"]);
const MUTATING_FILE_COMMANDS =
  "rm|rmdir|mv|cp|mkdir|touch|chmod|chown|chgrp|ln|tee|truncate|dd|shred";
const COMMAND_START = String.raw`(?:^|[;&|]\s*)(?:\w+=\S+\s+)*`;

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

function commandPattern(commands: string): RegExp {
  return new RegExp(`${COMMAND_START}(?:${commands})\\b`, "i");
}

function notifyPermissionRequest(pi: ExtensionAPI, ctx: ExtensionContext): void {
  if (!notificationsEnabled()) {
    return;
  }

  sendAlerterNotification(pi, ctx, {
    title: "Requesting Permission",
    group: "pi-coding-agent-permission",
    soundEnv: "PI_PERMISSION_SOUND",
    defaultSound: "Ping",
    timeoutEnv: "PI_PERMISSION_NOTIFICATION_TIMEOUT",
    defaultTimeoutSeconds: 15,
  });
}

function modeDescription(): string {
  if (accessMode === "readonly") {
    return [
      "Read-only work is allowed.",
      "Bash commands may run unless they look mutating or hard to inspect, such as file writes/redirections, mutating git or package-manager commands, background jobs, command substitution, or inline interpreter execution.",
      "File edit and write tools require user approval.",
      "Prefer straightforward inspection commands such as find, xargs, rg, grep, ls, head, tail, wc, git status/log/diff/show/ls-files, and simple read-only pipelines.",
    ].join(" ");
  }
  return "All available tools may run without an access-mode prompt.";
}

function normalizeCommand(command: string): string {
  return command.trim().replace(/\s+/g, " ");
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
      return true;
    }
    if (char === "&" && command[index - 1] !== "&" && command[index + 1] !== "&") {
      return true;
    }
  }
  return false;
}

function readonlyBashBlockReason(command: string): string | undefined {
  const normalized = normalizeCommand(command);
  if (!normalized) {
    return "empty command";
  }

  // Sending stderr to /dev/null is common for read-only probes and does not
  // mutate project files. Keep other redirections/background jobs ask-gated.
  const withoutBenignStderr = normalized.replace(/(^|\s)2>\s*\/dev\/null(?=\s|$)/g, " ");
  if (hasUnquotedShellWriteSyntax(withoutBenignStderr)) {
    return "shell redirection or background execution";
  }
  if (/[`]/.test(normalized) || normalized.includes("$(")) {
    return "command substitution can hide side effects";
  }

  const blocked = READONLY_BASH_DENYLIST.find(({ pattern }) => pattern.test(normalized));
  return blocked?.reason;
}

function bashPermission(input: Record<string, unknown>): PermissionDecision {
  if (typeof input.command !== "string") {
    return "ask";
  }

  return readonlyBashBlockReason(input.command) ? "ask" : "allow";
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
        reason: `Tool "${event.toolName}" requires approval${event.toolName === "bash" && typeof input.command === "string" ? ` (${readonlyBashBlockReason(input.command) ?? "not read-only"})` : ""}, but this deferred agent is running in readonly mode.`,
      };
    }

    if (!ctx.hasUI) {
      return {
        block: true,
        reason: `Tool "${event.toolName}" requires approval${event.toolName === "bash" && typeof input.command === "string" ? ` (${readonlyBashBlockReason(input.command) ?? "not read-only"})` : ""}, but no UI is available.`,
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

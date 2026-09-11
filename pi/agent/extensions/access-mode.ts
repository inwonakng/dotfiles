import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
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

export function bashMayMutate(command: string): boolean {
  return readonlyBashBlockReason(command) !== undefined;
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

  pi.on("tool_call", (event, ctx) => {
    setStatus(ctx);

    if (getAccessMode() === "write") {
      return undefined;
    }

    const reason = readonlyToolBlockReason(
      event.toolName,
      event.input as Record<string, unknown>,
    );
    return reason
      ? {
          block: true,
          reason: `Tool "${event.toolName}" blocked in readonly mode: ${reason}. Run /pi-mode write to allow mutating tools.`,
        }
      : undefined;
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

      setAccessMode(requestedMode);
      setStatus(ctx);
      ctx.ui.notify(`Access mode: ${getAccessMode()}`, "info");
    },
  });
}

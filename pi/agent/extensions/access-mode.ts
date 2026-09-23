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
import {
  isTrustedCommand, rememberCommand, reviewCommand, readonlyBashBlockReason, savedCommands,
} from "./shared/bash-access";

export { readonlyBashBlockReason } from "./shared/bash-access";

const READONLY_TOOLS = new Set(["read", "grep", "find", "ls", "web_search", "web_fetch"]);
const READONLY_WORKSPACE_ACTIONS = new Set(["status", "list"]);
const READONLY_SPAWN_CONTROL_ACTIONS = new Set(["list", "status", "join", "join_all"]);

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

function readonlyToolBlockReason(toolName: string, input: Record<string, unknown>, cwd: string): string | undefined {
  if (READONLY_TOOLS.has(toolName)) return undefined;
  if (toolName === "bash") {
    if (typeof input.command !== "string") return "bash requires a command that can be classified as read-only";
    const reason = readonlyBashBlockReason(input.command);
    if (!reason) return undefined;
    return isTrustedCommand(input.command, cwd) ? undefined : `bash command is not read-only: ${reason}`;
  }
  if (toolName === "workspace") {
    return typeof input.action === "string" && READONLY_WORKSPACE_ACTIONS.has(input.action)
      ? undefined : "workspace action is not whitelisted as read-only";
  }
  if (toolName === "spawn") {
    if (input.accessMode !== "readonly") return "spawn requires explicit accessMode=readonly";
    return input.isolation === undefined || input.isolation === "none"
      ? undefined : "spawn worktree isolation is not read-only";
  }
  if (toolName === "spawn_control") {
    return typeof input.action === "string" && READONLY_SPAWN_CONTROL_ACTIONS.has(input.action)
      ? undefined : "spawn_control action is not whitelisted as read-only";
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
    if (mode === "edit") return undefined;

    const input = event.input as Record<string, unknown>;
    if (event.toolName === "workspace" && workspaceManagesApproval(input)) return undefined;

    let reason: string | undefined;
    try {
      reason = readonlyToolBlockReason(event.toolName, input, ctx.cwd);
    } catch (error) {
      // A corrupt/unreadable trust store must never make an unknown command automatic.
      reason = `could not read bash access store: ${String(error)}`;
    }
    if (!reason) return undefined;

    if (event.toolName === "spawn" && (input.accessMode === "edit" || input.isolation === "worktree")) {
      return {
        block: true,
        reason: "Spawning edit-mode or isolated subagents requires parent access mode edit. Run /pi-mode edit before delegating edit work.",
      };
    }
    if (mode === "readonly") return { block: true, reason: `Tool "${event.toolName}" is blocked in readonly mode (${reason}).` };
    if (process.env.PI_SPAWN_AGENT === "1" || !ctx.hasUI) {
      const context = process.env.PI_SPAWN_AGENT === "1" ? "spawned subagents cannot request approval" : "no UI is available";
      return { block: true, reason: `Tool "${event.toolName}" requires approval (${reason}), but ${context}.` };
    }

    // Bash uses a three-way selection so Remember can never execute the command.
    if (event.toolName === "bash" && typeof input.command === "string") {
      const title = ctx.mode === "rpc" ? approvalPayload(event, ctx) : `Allow bash? ${input.command}`;
      const choice = await ctx.ui.select(title, ["Allow once", "Remember", "Deny"]);
      if (choice === "Allow once") return undefined;
      if (choice === "Remember") {
        const noteTitle = ctx.mode === "rpc"
          ? JSON.stringify({ kind: "pi_remember_note" })
          : "Optional reason for remembering command";
        const note = await ctx.ui.input(noteTitle);
        try {
          rememberCommand(input.command, ctx.cwd, note ?? "");
          ctx.ui.notify("Command remembered for review; not executed.", "info");
        } catch (error) {
          return { block: true, reason: `Could not remember bash command: ${String(error)}` };
        }
      }
      return { block: true, reason: `Tool "${event.toolName}" blocked by user.` };
    }

    const confirmed = await ctx.ui.confirm(`Allow ${event.toolName}?`, approvalPayload(event, ctx), { signal: ctx.signal });
    return confirmed ? undefined : { block: true, reason: `Tool "${event.toolName}" blocked by user.` };
  });

  pi.registerCommand("pi-bash-review", {
    description: "Review remembered bash commands and optionally trust an exact command in its directory",
    handler: async (_args, ctx) => {
      try {
        const store = savedCommands();
        const entries = [
          ...store.remembered.map((entry) => ({ entry, trusted: false })),
          ...store.trusted.map((entry) => ({ entry, trusted: true })),
        ];
        if (!entries.length) {
          ctx.ui.notify("No saved bash commands", "info");
          return;
        }
        const labels = entries.map(({ entry, trusted }, index) =>
          `${index + 1}. ${trusted ? "Trusted" : "Remembered"}: ${entry.command} (${entry.cwd})${entry.note ? ` — ${entry.note}` : ""}`,
        );
        const selected = await ctx.ui.select("Saved bash commands", labels);
        const index = labels.indexOf(selected ?? "");
        if (index < 0) return;
        const { entry, trusted } = entries[index];
        const choice = await ctx.ui.select(
          `Review bash command #${index + 1}`,
          trusted ? ["Keep trusted", "Revoke trust"] : ["Keep for later", "Trust exact command here", "Forget"],
        );
        if (choice === "Trust exact command here") {
          const confirmed = await ctx.ui.select("Auto-allow this exact command here on future runs?", ["Trust", "Cancel"]);
          if (confirmed !== "Trust") return;
          reviewCommand(entry, "trust");
          ctx.ui.notify("Exact command trusted in this directory", "info");
        } else if (choice === "Forget" || choice === "Revoke trust") {
          reviewCommand(entry, choice === "Forget" ? "forget" : "revoke");
          ctx.ui.notify(choice === "Forget" ? "Remembered command removed" : "Trust revoked", "info");
        }
      } catch (error) {
        ctx.ui.notify(`Could not review bash commands: ${String(error)}`, "error");
      }
    },
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

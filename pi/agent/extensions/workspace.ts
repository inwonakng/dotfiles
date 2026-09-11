import {
  SessionManager,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Type } from "typebox";
import { existsSync } from "node:fs";
import { bashMayMutate } from "./access-mode";
import {
  createWorkspace,
  formatWorkspaceRecord,
  getExpectedWorkspaceMissing,
  getPendingWorkspace,
  integrateWorkspace,
  linkedTaskForSession,
  listWorkspaces,
  loadWorkspace,
  prepareWorkspaceDiscard,
  removeWorkspace,
  saveWorkspace,
  setExpectedWorkspaceMissing,
  setPendingWorkspace,
  workspaceDisplayState,
  workspaceForContext,
  workspaceStorageRoot,
  type WorkspaceDisplayState,
  type WorkspaceRecord,
} from "./shared/workspace";

const WORKSPACE_ACTIONS = ["enter", "status", "list", "integrate", "discard"] as const;
type WorkspaceAction = (typeof WORKSPACE_ACTIONS)[number];

function sessionFile(ctx: ExtensionContext): string | undefined {
  return ctx.sessionManager.getSessionFile();
}

function displayLabel(state: WorkspaceDisplayState): string {
  const branch = state.branch ? ` (${state.branch})` : "";
  return `${state.name}${branch}`;
}

function publishWorkspaceState(ctx: ExtensionContext): void {
  const state = workspaceDisplayState(ctx.cwd, sessionFile(ctx));
  ctx.ui.setStatus(
    "pi-workspace",
    ctx.mode === "rpc" ? JSON.stringify(state) : `Workspace: ${displayLabel(state)}`,
  );
}

function queueCommand(pi: ExtensionAPI, command: string): void {
  pi.sendUserMessage(command, {
    deliverAs: "followUp",
    expandPromptTemplates: true,
  });
}

function taskForCurrentContext(ctx: ExtensionContext): WorkspaceRecord | undefined {
  const active = workspaceForContext(ctx.cwd, sessionFile(ctx));
  return active?.kind === "task" ? active : undefined;
}

function formatStatus(ctx: ExtensionContext): string {
  const state = workspaceDisplayState(ctx.cwd, sessionFile(ctx));
  const lines = [
    `Workspace: ${displayLabel(state)}`,
    `- lifecycle: ${state.lifecycle}`,
    `- cwd: ${state.cwd}`,
    `- path: ${state.path}`,
    `- session: ${state.sessionFile ?? "ephemeral"}`,
    `- storage: ${workspaceStorageRoot()}`,
  ];
  if (state.id) lines.push(`- id: ${state.id}`);
  const linked = linkedTaskForSession(sessionFile(ctx));
  if (linked && linked.id !== state.id) {
    lines.push(`- linked task: ${linked.id} (${linked.lifecycle})`);
    lines.push(`- linked worktree: ${linked.worktreePath}`);
  }
  const pending = getPendingWorkspace();
  if (pending) lines.push(`- transition pending: ${pending.id}`);
  const missing = getExpectedWorkspaceMissing();
  if (missing) lines.push(`- missing expected workspace: ${missing}`);
  return lines.join("\n");
}

function shouldBlockMutation(
  toolName: string,
  input: Record<string, unknown>,
  ctx: ExtensionContext,
): string | undefined {
  const active = workspaceForContext(ctx.cwd, sessionFile(ctx));
  if (active && existsSync(active.worktreePath)) {
    return undefined;
  }
  const pending = getPendingWorkspace();
  const missing = getExpectedWorkspaceMissing();
  let mutating = toolName === "edit" || toolName === "write";
  if (toolName === "bash" && typeof input.command === "string") {
    mutating = bashMayMutate(input.command);
  }
  if (toolName === "spawn") {
    mutating = input.accessMode === "write" || input.isolation === "worktree";
  }
  if (!mutating) {
    return undefined;
  }
  if (missing) {
    return `Expected Pi workspace ${missing} is missing. Inspect or discard the retained workspace record before editing.`;
  }
  if (pending) {
    return `Workspace transition to ${pending.id} is pending. Wait for the linked continuation session before editing.`;
  }
  return "Implementation edits require a task workspace. Call the workspace tool with action=enter first.";
}

async function confirmDestructive(
  ctx: ExtensionContext,
  title: string,
  message: string,
  approved: boolean | undefined,
): Promise<boolean> {
  if (ctx.hasUI) {
    return ctx.ui.confirm(title, message, { signal: ctx.signal });
  }
  return approved === true;
}

export default function workspaceExtension(pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    const envWorkspaceId = process.env.PI_WORKSPACE_ID;
    if (envWorkspaceId) {
      const record = loadWorkspace(envWorkspaceId);
      const missing = !record || !record.retained || !existsSync(record.worktreePath);
      setExpectedWorkspaceMissing(missing ? envWorkspaceId : undefined);
    } else {
      const linked = linkedTaskForSession(sessionFile(ctx));
      const missing = linked && (!existsSync(linked.worktreePath) || !linked.retained) ? linked.id : undefined;
      setExpectedWorkspaceMissing(missing);
    }
    publishWorkspaceState(ctx);
  });

  pi.on("tool_call", (event, ctx) => {
    const reason = shouldBlockMutation(event.toolName, event.input as Record<string, unknown>, ctx);
    return reason ? { block: true, reason, terminate: true } : undefined;
  });

  pi.registerCommand("pi-workspace-enter", {
    description: "Internal command that moves the active conversation into a task workspace",
    handler: async (args, ctx) => {
      const id = args.trim();
      const record = loadWorkspace(id);
      if (!record || record.kind !== "task") {
        throw new Error(`Unknown task workspace: ${id}`);
      }
      try {
        await ctx.waitForIdle();
        let targetSessionFile = record.targetSessionFile;
        if (!targetSessionFile || !existsSync(targetSessionFile)) {
          const source = ctx.sessionManager.getSessionFile();
          if (!source || !existsSync(source)) {
            throw new Error("Workspace entry requires a persisted source session.");
          }
          const target = SessionManager.forkFrom(source, record.workspaceCwd);
          targetSessionFile = target.getSessionFile();
          if (!targetSessionFile) {
            throw new Error("Could not create the workspace continuation session.");
          }
          record.sourceSessionFile = record.sourceSessionFile ?? source;
          record.targetSessionFile = targetSessionFile;
          saveWorkspace(record);
        }
        const result = await ctx.switchSession(targetSessionFile, {
          withSession: async (nextCtx) => {
            setPendingWorkspace(undefined);
            setExpectedWorkspaceMissing(undefined);
            publishWorkspaceState(nextCtx);
            nextCtx.ui.notify(`Entered workspace ${record.label}.`, "info");
          },
        });
        if (result.cancelled) {
          throw new Error("Workspace session switch was cancelled.");
        }
      } catch (error) {
        setPendingWorkspace(undefined);
        record.lifecycle = "retained";
        record.integrationReason = error instanceof Error ? error.message : String(error);
        saveWorkspace(record);
        throw error;
      }
    },
  });

  pi.registerCommand("pi-workspace-return", {
    description: "Internal command that returns a completed task conversation to its origin checkout",
    handler: async (args, ctx) => {
      const id = args.trim();
      const record = loadWorkspace(id);
      if (!record || record.kind !== "task") {
        throw new Error(`Unknown task workspace: ${id}`);
      }
      await ctx.waitForIdle();
      const source = ctx.sessionManager.getSessionFile();
      if (!source || !existsSync(source)) {
        throw new Error("Workspace return requires a persisted workspace session.");
      }
      const continuation = SessionManager.forkFrom(source, record.destinationCwd);
      const continuationFile = continuation.getSessionFile();
      if (!continuationFile) {
        throw new Error("Could not create the origin continuation session.");
      }
      record.continuationSessionFile = continuationFile;
      saveWorkspace(record);
      const result = await ctx.switchSession(continuationFile, {
        withSession: async (nextCtx) => {
          const finalLifecycle = record.lifecycle === "discard_pending" ? "discarded" : "integrated";
          const cleaned = removeWorkspace(record.id, finalLifecycle);
          setPendingWorkspace(undefined);
          publishWorkspaceState(nextCtx);
          if (cleaned.lifecycle === "cleanup_failed") {
            nextCtx.ui.notify(
              `Returned to the origin checkout, but workspace cleanup failed: ${cleaned.integrationReason ?? cleaned.worktreePath}`,
              "warning",
            );
          } else {
            nextCtx.ui.notify(
              finalLifecycle === "integrated"
                ? `Integrated ${record.label} and returned to the origin checkout.`
                : `Discarded ${record.label} and returned to the origin checkout.`,
              "info",
            );
          }
        },
      });
      if (result.cancelled) {
        throw new Error("Return to the origin checkout was cancelled; the workspace was retained.");
      }
    },
  });

  pi.registerCommand("pi-workspace-publish", {
    description: "Publish the current workspace state to the active host",
    handler: async (_args, ctx) => {
      publishWorkspaceState(ctx);
    },
  });

  pi.registerCommand("pi-workspace", {
    description: "Show Pi workspace status or list retained workspaces",
    handler: async (args, ctx) => {
      const action = args.trim() || "status";
      if (action === "status") {
        publishWorkspaceState(ctx);
        ctx.ui.notify(formatStatus(ctx), "info");
        return;
      }
      if (action === "list") {
        const records = listWorkspaces();
        ctx.ui.notify(records.length > 0 ? records.map(formatWorkspaceRecord).join("\n\n") : "No Pi workspaces.", "info");
        return;
      }
      ctx.ui.notify("Usage: /pi-workspace status|list", "warning");
    },
  });

  pi.registerTool({
    name: "workspace",
    label: "Workspace",
    description: "Create/reuse a task worktree, inspect workspace state, explicitly integrate a completed task, or discard retained work. Top-level integration is never automatic. Status includes full workspace paths.",
    promptSnippet: "Manage the current task's isolated Git worktree and explicit integration lifecycle.",
    promptGuidelines: [
      "Call workspace with action=enter before the first implementation edit unless the current session is already in an associated workspace.",
      "Call workspace with action=status when the expected workspace is missing or its lifecycle is unclear.",
      "Call workspace with action=integrate only after the user explicitly approves top-level integration.",
    ],
    parameters: Type.Object({
      action: StringEnum(WORKSPACE_ACTIONS, { description: "Workspace lifecycle action." }),
      id: Type.Optional(Type.String({ description: "Workspace id for enter, status, integration, or discard; defaults to the linked or active workspace." })),
      approved: Type.Optional(Type.Boolean({ description: "Required for destructive operations when no interactive UI is available." })),
    }),
    executionMode: "sequential",
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const action = params.action as WorkspaceAction;
      if (action === "status") {
        const record = params.id ? loadWorkspace(params.id) : workspaceForContext(ctx.cwd, sessionFile(ctx));
        const text = record ? formatWorkspaceRecord(record) : formatStatus(ctx);
        publishWorkspaceState(ctx);
        return { content: [{ type: "text", text }], details: record ?? workspaceDisplayState(ctx.cwd, sessionFile(ctx)) };
      }
      if (action === "list") {
        const records = listWorkspaces();
        return {
          content: [{ type: "text", text: records.length > 0 ? records.map(formatWorkspaceRecord).join("\n\n") : "No Pi workspaces." }],
          details: { records },
        };
      }
      if (action === "enter") {
        const active = taskForCurrentContext(ctx);
        if (active && existsSync(active.worktreePath)) {
          publishWorkspaceState(ctx);
          return {
            content: [{ type: "text", text: `Already in task workspace.\n${formatWorkspaceRecord(active)}` }],
            details: active,
          };
        }
        const source = sessionFile(ctx);
        let record = params.id ? loadWorkspace(params.id) : linkedTaskForSession(source);
        if (record && record.kind !== "task") {
          throw new Error(`Workspace ${record.id} is a child workspace; resume it through spawn_control.`);
        }
        if (!record) {
          if (params.id) {
            throw new Error(`Unknown task workspace: ${params.id}`);
          }
          record = createWorkspace({
            kind: "task",
            destinationCwd: ctx.cwd,
            sourceSessionFile: source,
          });
        }
        if (!existsSync(record.worktreePath)) {
          setExpectedWorkspaceMissing(record.id);
          throw new Error(`Retained workspace record points to a missing path: ${record.worktreePath}`);
        }
        setPendingWorkspace(record.id);
        queueCommand(pi, `/pi-workspace-enter ${record.id}`);
        return {
          content: [{ type: "text", text: `Workspace ${record.label} is ready. Switching the linked continuation to ${record.workspaceCwd}.` }],
          details: record,
          terminate: true,
        };
      }

      const selected = params.id ? loadWorkspace(params.id) : workspaceForContext(ctx.cwd, sessionFile(ctx));
      if (!selected) {
        throw new Error(`No workspace available for action=${action}.`);
      }
      if (action === "integrate") {
        if (selected.kind !== "task") {
          throw new Error("Top-level workspace integration only applies to task workspaces; child workspaces integrate through spawn_control.");
        }
        const active = taskForCurrentContext(ctx);
        if (!active || active.id !== selected.id) {
          throw new Error(`Enter task workspace ${selected.id} before integrating it so the linked conversation can return safely.`);
        }
        const confirmed = await confirmDestructive(
          ctx,
          "Integrate task workspace?",
          `Apply ${selected.label} to ${selected.destinationRoot} and return to the origin checkout?`,
          params.approved,
        );
        if (!confirmed) {
          return { content: [{ type: "text", text: "Workspace integration was not approved." }], details: selected };
        }
        const integrated = await integrateWorkspace(selected.id);
        if (integrated.integration !== "applied" && integrated.integration !== "none") {
          return {
            content: [{ type: "text", text: `Workspace was retained; integration=${integrated.integration}.\n${formatWorkspaceRecord(integrated)}` }],
            details: integrated,
          };
        }
        setPendingWorkspace(integrated.id);
        queueCommand(pi, `/pi-workspace-return ${integrated.id}`);
        return {
          content: [{ type: "text", text: `Applied the task contribution to ${integrated.destinationRoot}. Returning to the origin checkout before cleanup.` }],
          details: integrated,
          terminate: true,
        };
      }

      const prepared = prepareWorkspaceDiscard(selected.id);
      const changed = prepared.changedFiles.length > 0 ? prepared.changedFiles.join("\n") : "(no changed files)";
      const unpreserved = prepared.unpreservedFiles && prepared.unpreservedFiles.length > 0
        ? `\n\nIgnored untracked files not included in the recovery patch:\n${prepared.unpreservedFiles.join("\n")}`
        : "";
      const confirmed = await confirmDestructive(
        ctx,
        "Discard workspace?",
        `Discard ${prepared.label} and remove its worktree?\n\nWorkspace changes:\n${changed}${unpreserved}\n\nRecovery patch: ${prepared.resultPatchPath}`,
        params.approved,
      );
      if (!confirmed) {
        return { content: [{ type: "text", text: "Workspace discard was not approved." }], details: prepared };
      }
      const active = workspaceForContext(ctx.cwd, sessionFile(ctx));
      if (prepared.kind === "task" && active?.id === prepared.id) {
        prepared.lifecycle = "discard_pending";
        saveWorkspace(prepared);
        setPendingWorkspace(prepared.id);
        queueCommand(pi, `/pi-workspace-return ${prepared.id}`);
        return {
          content: [{ type: "text", text: "Discard approved. Returning to the origin checkout before removing the active worktree." }],
          details: prepared,
          terminate: true,
        };
      }
      const discarded = removeWorkspace(prepared.id, "discarded");
      return {
        content: [{ type: "text", text: discarded.lifecycle === "cleanup_failed"
          ? `Discard cleanup failed; workspace retained: ${discarded.integrationReason ?? discarded.worktreePath}`
          : `Discarded ${discarded.label}. Recovery patch: ${discarded.resultPatchPath}` }],
        details: discarded,
      };
    },
  });
}

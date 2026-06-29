import { CONFIG_DIR_NAME, getAgentDir, parseFrontmatter, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { randomUUID } from "node:crypto";
import { existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

const ACCESS_MODES = ["readonly", "write"] as const;
type AccessMode = (typeof ACCESS_MODES)[number];

type RpcEvent = Record<string, unknown>;

type PendingRequest = {
  resolve: (event: RpcEvent) => void;
  reject: (error: Error) => void;
};

type SubagentProfile = {
  name: string;
  description: string;
  systemPrompt: string;
  source: "user" | "project";
  filePath: string;
  tools?: string[];
  model?: string;
  accessMode?: AccessMode;
};

class PiRpcChild {
  private proc: ChildProcessWithoutNullStreams;
  private pending = new Map<string, PendingRequest>();
  private nextId = 0;
  private stdoutBuffer = "";
  private stderrBuffer = "";
  private ended = false;
  private agentEndResolver: ((event: RpcEvent) => void) | undefined;
  private agentEndRejecter: ((error: Error) => void) | undefined;

  constructor(
    argv: string[],
    options: { cwd: string; env: NodeJS.ProcessEnv; onEvent: (event: RpcEvent) => void },
  ) {
    this.proc = spawn(argv[0], argv.slice(1), {
      cwd: options.cwd,
      env: options.env,
      stdio: ["pipe", "pipe", "pipe"],
    });

    this.proc.stdout.on("data", (chunk) => {
      this.stdoutBuffer += chunk.toString("utf8");
      this.drainLines(this.stdoutBuffer, (remaining) => {
        this.stdoutBuffer = remaining;
      }, (line) => this.handleStdoutLine(line, options.onEvent));
    });

    this.proc.stderr.on("data", (chunk) => {
      this.stderrBuffer += chunk.toString("utf8");
      this.drainLines(this.stderrBuffer, (remaining) => {
        this.stderrBuffer = remaining;
      }, (line) => {
        options.onEvent({ type: "child_stderr", text: line });
      });
    });

    this.proc.on("error", (error) => {
      this.rejectAll(error);
    });

    this.proc.on("exit", (code, signal) => {
      this.ended = true;
      const error = new Error(`subagent pi exited before completion: code=${code ?? "null"} signal=${signal ?? "null"}`);
      this.rejectAll(error);
      this.agentEndRejecter?.(error);
      options.onEvent({ type: "child_exit", code, signal });
    });
  }

  abort(): void {
    if (!this.ended) {
      this.proc.kill("SIGTERM");
    }
  }

  dispose(): void {
    if (!this.ended) {
      this.proc.kill("SIGTERM");
    }
  }

  send(command: RpcEvent): Promise<RpcEvent> {
    if (this.ended) {
      return Promise.reject(new Error("subagent pi process already exited"));
    }
    const id = `defer-${++this.nextId}`;
    command.id = id;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.proc.stdin.write(`${JSON.stringify(command)}\n`, (error) => {
        if (error) {
          this.pending.delete(id);
          reject(error);
        }
      });
    });
  }

  waitForAgentEnd(): Promise<RpcEvent> {
    return new Promise((resolve, reject) => {
      this.agentEndResolver = resolve;
      this.agentEndRejecter = reject;
    });
  }

  private drainLines(
    buffer: string,
    setRemaining: (value: string) => void,
    onLine: (line: string) => void,
  ): void {
    while (true) {
      const index = buffer.indexOf("\n");
      if (index === -1) {
        setRemaining(buffer);
        return;
      }
      let line = buffer.slice(0, index);
      buffer = buffer.slice(index + 1);
      if (line.endsWith("\r")) {
        line = line.slice(0, -1);
      }
      if (line !== "") {
        onLine(line);
      }
    }
  }

  private handleStdoutLine(line: string, onEvent: (event: RpcEvent) => void): void {
    let event: RpcEvent;
    try {
      event = JSON.parse(line) as RpcEvent;
    } catch (error) {
      onEvent({ type: "child_bad_json", line, error: String(error) });
      return;
    }

    onEvent(event);

    if (event.type === "response" && typeof event.id === "string") {
      const pending = this.pending.get(event.id);
      if (pending) {
        this.pending.delete(event.id);
        pending.resolve(event);
      }
      return;
    }

    if (event.type === "extension_ui_request" && typeof event.id === "string") {
      this.handleExtensionUiRequest(event);
      return;
    }

    if (event.type === "agent_end") {
      this.agentEndResolver?.(event);
      this.agentEndResolver = undefined;
      this.agentEndRejecter = undefined;
    }
  }

  private handleExtensionUiRequest(event: RpcEvent): void {
    const id = event.id;
    if (typeof id !== "string") {
      return;
    }
    const method = event.method;
    const response: RpcEvent = { type: "extension_ui_response", id };
    if (method === "confirm") {
      response.confirmed = false;
    } else {
      response.cancelled = true;
    }
    this.proc.stdin.write(`${JSON.stringify(response)}\n`);
  }

  private rejectAll(error: Error): void {
    for (const pending of this.pending.values()) {
      pending.reject(error);
    }
    this.pending.clear();
  }
}

function textFromLastAssistantResponse(event: RpcEvent): string | undefined {
  const data = event.data as { text?: unknown } | undefined;
  return typeof data?.text === "string" ? data.text : undefined;
}

function assertSuccess(event: RpcEvent, action: string): void {
  if (event.success === false) {
    throw new Error(`${action} failed: ${String(event.error ?? "unknown error")}`);
  }
}

function compactOneLine(value: unknown, maxLength = 96): string {
  if (typeof value !== "string") {
    return "";
  }
  const compact = value.replace(/\r\n/g, "\n").replace(/\r/g, "\n").replace(/\n/g, " ⏎ ").replace(/\s+/g, " ").trim();
  return compact.length > maxLength ? `${compact.slice(0, Math.max(0, maxLength - 1))}…` : compact;
}

function pathBasename(path: unknown): string | undefined {
  if (typeof path !== "string" || path === "") {
    return undefined;
  }
  return path.split(/[\\/]/).filter(Boolean).pop() ?? path;
}

function previewToolArgs(toolName: unknown, args: unknown): string {
  if (typeof toolName !== "string" || typeof args !== "object" || args === null) {
    return "";
  }
  const input = args as Record<string, unknown>;
  if (toolName === "read") {
    const path = pathBasename(input.path);
    return path ? ` ${path}` : "";
  }
  if (toolName === "bash") {
    const command = compactOneLine(input.command, 72);
    return command ? ` ${command}` : "";
  }
  if (toolName === "web_fetch") {
    const url = compactOneLine(input.url, 72);
    return url ? ` ${url}` : "";
  }
  if (toolName === "web_search") {
    const query = compactOneLine(input.query, 72);
    return query ? ` ${query}` : "";
  }
  return "";
}

function parseCsv(value: string | undefined): string[] | undefined {
  const items = value?.split(",").map((item) => item.trim()).filter(Boolean) ?? [];
  return items.length > 0 ? items : undefined;
}

function parseAccessMode(value: string | undefined): AccessMode | undefined {
  const trimmed = value?.trim();
  return trimmed === "readonly" || trimmed === "write" ? trimmed : undefined;
}

function isDirectory(path: string): boolean {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
}

function findNearestProjectAgentsDir(cwd: string): string | undefined {
  let current = cwd;
  while (true) {
    const candidate = join(current, CONFIG_DIR_NAME, "agents");
    if (isDirectory(candidate)) {
      return candidate;
    }
    const parent = dirname(current);
    if (parent === current) {
      return undefined;
    }
    current = parent;
  }
}

function loadSubagentProfilesFromDir(dir: string, source: "user" | "project"): SubagentProfile[] {
  if (!existsSync(dir)) {
    return [];
  }

  let entries;
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return [];
  }

  const profiles: SubagentProfile[] = [];
  for (const entry of entries) {
    if (!entry.name.endsWith(".md") || (!entry.isFile() && !entry.isSymbolicLink())) {
      continue;
    }

    const filePath = join(dir, entry.name);
    let content: string;
    try {
      content = readFileSync(filePath, "utf8");
    } catch {
      continue;
    }

    const { frontmatter, body } = parseFrontmatter<Record<string, string>>(content);
    const name = frontmatter.name?.trim();
    const description = frontmatter.description?.trim();
    if (!name || !description) {
      continue;
    }

    profiles.push({
      name,
      description,
      systemPrompt: body.trim(),
      source,
      filePath,
      tools: parseCsv(frontmatter.tools),
      model: frontmatter.model?.trim() || undefined,
      accessMode: parseAccessMode(frontmatter.accessMode) ?? parseAccessMode(frontmatter.defaultAccessMode),
    });
  }

  return profiles;
}

function discoverSubagentProfiles(cwd: string, includeProject: boolean): SubagentProfile[] {
  const profileMap = new Map<string, SubagentProfile>();

  for (const profile of loadSubagentProfilesFromDir(join(getAgentDir(), "agents"), "user")) {
    profileMap.set(profile.name, profile);
  }

  if (includeProject) {
    const projectAgentsDir = findNearestProjectAgentsDir(cwd);
    if (projectAgentsDir) {
      for (const profile of loadSubagentProfilesFromDir(projectAgentsDir, "project")) {
        profileMap.set(profile.name, profile);
      }
    }
  }

  return Array.from(profileMap.values());
}

function formatProfileList(profiles: SubagentProfile[]): string {
  if (profiles.length === 0) {
    return "none discovered";
  }
  return profiles.map((profile) => `${profile.name} (${profile.source}): ${profile.description}`).join("; ");
}

function resolveSubagentProfile(input: {
  agent?: string;
  role?: string;
  profiles: SubagentProfile[];
}): SubagentProfile | undefined {
  const explicitAgent = input.agent?.trim();
  const role = input.role?.trim();
  const requested = explicitAgent || role;
  if (!requested) {
    return undefined;
  }

  const profile = input.profiles.find((candidate) => candidate.name === requested);
  if (!profile && explicitAgent) {
    throw new Error(`Unknown subagent profile: ${explicitAgent}. Available profiles: ${formatProfileList(input.profiles)}`);
  }
  return profile;
}

function subagentSystemPrompt(profile: SubagentProfile, accessMode: AccessMode): string {
  return `You are the ${profile.name} subagent in a pi parent session.

Description: ${profile.description}
Source: ${profile.source} (${profile.filePath})
Access mode for this invocation: ${accessMode}

${profile.systemPrompt}`;
}

function deferPrompt(input: {
  task: string;
  role?: string;
  agent?: SubagentProfile;
  accessMode: AccessMode;
  briefPath: string;
  agentPromptPath?: string;
}): string {
  const role = input.role?.trim() || input.agent?.name || "general subagent";
  const agentSection = input.agent
    ? `Subagent profile: ${input.agent.name}
Description: ${input.agent.description}
Profile path: ${input.agent.filePath}${input.agentPromptPath ? `\nLoaded prompt artifact: ${input.agentPromptPath}` : ""}`
    : "Subagent profile: none (generic deferred subagent)";

  return `You are a subagent working inside a pi parent session.

Role: ${role}
${agentSection}
Access mode: ${input.accessMode}
Task brief path: ${input.briefPath}

Instructions:
- Read the task carefully and do only that task.
- Keep exploration targeted.
- Do not ask the parent for permission. If access is blocked or information is missing, stop and report BLOCKED.
- If access mode is readonly, do not attempt to modify files.
- Return a concise final report with one of these statuses: DONE, BLOCKED, or NEEDS_CONTEXT.
- Include key evidence: files inspected, commands run, findings, and any artifact paths.

Task:
${input.task}`;
}

function resultSummary(
  text: string,
  resultPath: string,
  transcriptPath: string,
  briefPath: string,
  statusPath: string,
  agentPromptPath?: string,
): string {
  const trimmed = text.trim() || "Subagent produced no final text.";
  const agentPromptLine = agentPromptPath ? `\n- Subagent prompt: ${agentPromptPath}` : "";
  return `${trimmed}\n\nArtifacts:\n- Brief: ${briefPath}\n- Result: ${resultPath}\n- Transcript: ${transcriptPath}\n- Status: ${statusPath}${agentPromptLine}`;
}

export default function deferExtension(pi: ExtensionAPI) {
  if (process.env.PI_DEFER_AGENT === "1") {
    return;
  }

  pi.registerTool({
    name: "defer_task",
    label: "Subagent Task",
    description: "Run a bounded task in an isolated pi subagent. Supports named subagent profiles from ~/.pi/agent/agents/*.md and trusted .pi/agents/*.md; artifacts are written under the project's .pi/defer directory.",
    promptSnippet: "Run bounded isolated pi subagents for research, planning, review, or implementation.",
    promptGuidelines: [
      "Use defer_task as the subagent mechanism when the user says 'use subagents' or invokes /subagents, and for bounded work that benefits from isolated context.",
      "Prefer defer_task agent profiles such as researcher, planner, implementer, reviewer, or verifier when they match; load the defer skill for non-trivial delegation policy before coordinating subagents.",
    ],
    parameters: Type.Object({
      task: Type.String({ description: "The complete bounded task for the subagent." }),
      agent: Type.Optional(Type.String({ description: "Named subagent profile to load from ~/.pi/agent/agents/*.md or trusted .pi/agents/*.md, e.g. researcher, planner, implementer, reviewer." })),
      role: Type.Optional(Type.String({ description: "Backward-compatible role/instructions label. If it matches a subagent profile and agent is omitted, that profile is loaded." })),
      accessMode: Type.Optional(Type.Union([
        Type.Literal("readonly"),
        Type.Literal("write"),
      ], { description: "Subagent access mode. Defaults to the profile accessMode, otherwise readonly." })),
      model: Type.Optional(Type.String({ description: "Optional pi --model value for the subagent. Defaults to the profile model, otherwise inherits the parent invocation default." })),
      timeoutSeconds: Type.Optional(Type.Number({ description: "Optional timeout in seconds. Defaults to 1800." })),
    }),
    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      const includeProjectAgents = typeof ctx.isProjectTrusted === "function" ? ctx.isProjectTrusted() : false;
      const profiles = discoverSubagentProfiles(ctx.cwd, includeProjectAgents);
      const subagent = resolveSubagentProfile({ agent: params.agent, role: params.role, profiles });
      const accessMode = (params.accessMode ?? subagent?.accessMode ?? "readonly") as AccessMode;
      if (!ACCESS_MODES.includes(accessMode)) {
        throw new Error(`Invalid accessMode: ${String(params.accessMode)}`);
      }

      const runId = `${new Date().toISOString().replace(/[:.]/g, "-")}-${randomUUID().slice(0, 8)}`;
      const deferRoot = resolve(ctx.cwd, CONFIG_DIR_NAME, "defer");
      const runDir = join(deferRoot, runId);
      mkdirSync(runDir, { recursive: true });

      const briefPath = join(runDir, "brief.md");
      const transcriptPath = join(runDir, "transcript.jsonl");
      const resultPath = join(runDir, "result.md");
      const statusPath = join(runDir, "status.json");
      const agentPromptPath = subagent ? join(runDir, "subagent-prompt.md") : undefined;

      writeFileSync(briefPath, params.task, "utf8");
      if (subagent && agentPromptPath) {
        writeFileSync(agentPromptPath, subagentSystemPrompt(subagent, accessMode), "utf8");
      }
      writeFileSync(statusPath, JSON.stringify({
        status: "running",
        runId,
        accessMode,
        role: params.role ?? null,
        agent: subagent?.name ?? params.agent ?? null,
        agentSource: subagent?.source ?? null,
        agentProfilePath: subagent?.filePath ?? null,
        startedAt: new Date().toISOString(),
      }, null, 2), "utf8");

      const binary = process.env.PI_BINARY || "pi";
      const argv = [binary, "--mode", "rpc", "--no-session"];
      const model = params.model ?? (subagent?.model && subagent.model !== "inherit" ? subagent.model : undefined);
      if (model) {
        argv.push("--model", model);
      }
      if (subagent?.tools && subagent.tools.length > 0) {
        argv.push("--tools", subagent.tools.join(","));
      }
      if (agentPromptPath) {
        argv.push("--append-system-prompt", agentPromptPath);
      }

      const artifactDetails = {
        runId,
        runDir,
        briefPath,
        resultPath,
        transcriptPath,
        statusPath,
        agentPromptPath,
        accessMode,
        role: params.role ?? null,
        agent: subagent?.name ?? params.agent ?? null,
        agentSource: subagent?.source ?? null,
        agentProfilePath: subagent?.filePath ?? null,
      };
      const label = subagent?.name ? `${subagent.name} subagent` : "Subagent";
      let latestProgress = `${label} ${runId} starting (${accessMode}).`;
      let assistantPreview = "";
      let progressTimer: NodeJS.Timeout | undefined;
      const publishProgress = (text: string, immediate = false) => {
        latestProgress = text;
        const emit = () => {
          progressTimer = undefined;
          onUpdate?.({
            content: [{ type: "text", text: latestProgress }],
            details: { ...artifactDetails, status: "running", progress: latestProgress },
          });
        };
        if (immediate) {
          if (progressTimer) {
            clearTimeout(progressTimer);
            progressTimer = undefined;
          }
          emit();
          return;
        }
        if (!progressTimer) {
          progressTimer = setTimeout(emit, 150);
        }
      };
      const summarizeChildEvent = (event: RpcEvent): string | undefined => {
        if (event.type === "agent_start") {
          return `${label} ${runId} started (${accessMode}).`;
        }
        if (event.type === "turn_start") {
          return `${label} thinking…`;
        }
        if (event.type === "tool_execution_start") {
          const toolName = typeof event.toolName === "string" ? event.toolName : "tool";
          return `${label} running ${toolName}${previewToolArgs(toolName, event.args)}.`;
        }
        if (event.type === "tool_execution_end") {
          const toolName = typeof event.toolName === "string" ? event.toolName : "tool";
          return `${label} completed ${toolName}.`;
        }
        if (event.type === "message_update") {
          const update = event.assistantMessageEvent as { type?: unknown; delta?: unknown } | undefined;
          if (update?.type === "text_delta" && typeof update.delta === "string") {
            assistantPreview = compactOneLine(`${assistantPreview}${update.delta}`, 120);
            if (assistantPreview) {
              return `${label} writing final report: ${assistantPreview}`;
            }
          }
        }
        if (event.type === "child_stderr") {
          const text = compactOneLine(event.text, 120);
          return text ? `${label} stderr: ${text}` : undefined;
        }
        if (event.type === "child_exit") {
          return `${label} process exited: code=${String(event.code ?? "null")} signal=${String(event.signal ?? "null")}.`;
        }
        return undefined;
      };

      const transcript = (event: RpcEvent) => {
        writeFileSync(transcriptPath, `${JSON.stringify({ timestamp: new Date().toISOString(), event })}\n`, { flag: "a" });
        const progress = summarizeChildEvent(event);
        if (progress) {
          publishProgress(progress);
        }
      };

      const childEnv: NodeJS.ProcessEnv = {
        ...process.env,
        PI_DEFER_AGENT: "1",
        PI_DEFER_ACCESS_MODE: accessMode,
        PI_SUBAGENT_NAME: subagent?.name ?? params.agent ?? params.role ?? "",
      };
      if (process.env.PI_CODING_AGENT_DIR) {
        childEnv.PI_CODING_AGENT_DIR = process.env.PI_CODING_AGENT_DIR;
      }

      const child = new PiRpcChild(argv, {
        cwd: ctx.cwd,
        env: childEnv,
        onEvent: transcript,
      });

      const timeoutMs = Math.max(1, params.timeoutSeconds ?? 1800) * 1000;
      const timeout = setTimeout(() => child.abort(), timeoutMs);
      const abort = () => child.abort();
      signal?.addEventListener("abort", abort, { once: true });

      try {
        publishProgress(`${label} ${runId} started (${accessMode}).`, true);
        const agentEnd = child.waitForAgentEnd();
        const promptResponse = await child.send({ type: "prompt", message: deferPrompt({ task: params.task, role: params.role, agent: subagent, accessMode, briefPath, agentPromptPath }) });
        assertSuccess(promptResponse, "subagent prompt");
        await agentEnd;
        const lastAssistant = await child.send({ type: "get_last_assistant_text" });
        assertSuccess(lastAssistant, "get subagent result");
        const resultText = textFromLastAssistantResponse(lastAssistant) ?? "";
        writeFileSync(resultPath, resultText, "utf8");
        writeFileSync(statusPath, JSON.stringify({
          status: "done",
          runId,
          accessMode,
          role: params.role ?? null,
          agent: subagent?.name ?? params.agent ?? null,
          agentSource: subagent?.source ?? null,
          agentProfilePath: subagent?.filePath ?? null,
          completedAt: new Date().toISOString(),
          briefPath,
          resultPath,
          transcriptPath,
          agentPromptPath,
        }, null, 2), "utf8");
        return {
          content: [{ type: "text", text: resultSummary(resultText, resultPath, transcriptPath, briefPath, statusPath, agentPromptPath) }],
          details: { ...artifactDetails, status: "done" },
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        writeFileSync(resultPath, `Subagent failed: ${message}\n`, "utf8");
        writeFileSync(statusPath, JSON.stringify({
          status: "error",
          runId,
          accessMode,
          role: params.role ?? null,
          agent: subagent?.name ?? params.agent ?? null,
          agentSource: subagent?.source ?? null,
          agentProfilePath: subagent?.filePath ?? null,
          error: message,
          completedAt: new Date().toISOString(),
          briefPath,
          resultPath,
          transcriptPath,
          agentPromptPath,
        }, null, 2), "utf8");
        return {
          content: [{ type: "text", text: `Subagent failed: ${message}\n\nArtifacts:\n- Brief: ${briefPath}\n- Result: ${resultPath}\n- Transcript: ${transcriptPath}\n- Status: ${statusPath}${agentPromptPath ? `\n- Subagent prompt: ${agentPromptPath}` : ""}` }],
          isError: true,
          details: { ...artifactDetails, status: "error", error: message },
        };
      } finally {
        clearTimeout(timeout);
        if (progressTimer) {
          clearTimeout(progressTimer);
        }
        signal?.removeEventListener("abort", abort);
        child.dispose();
      }
    },
  });
}

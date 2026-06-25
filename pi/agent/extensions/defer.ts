import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { randomUUID } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

const ACCESS_MODES = ["readonly", "write"] as const;
type AccessMode = (typeof ACCESS_MODES)[number];

type RpcEvent = Record<string, unknown>;

type PendingRequest = {
  resolve: (event: RpcEvent) => void;
  reject: (error: Error) => void;
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
      const error = new Error(`deferred pi exited before completion: code=${code ?? "null"} signal=${signal ?? "null"}`);
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
      return Promise.reject(new Error("deferred pi process already exited"));
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

function deferPrompt(input: { task: string; role?: string; accessMode: AccessMode; briefPath: string }): string {
  const role = input.role?.trim() || "general deferred subagent";
  return `You are a deferred subagent working inside a pi parent session.

Role: ${role}
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

function resultSummary(text: string, resultPath: string, transcriptPath: string, briefPath: string, statusPath: string): string {
  const trimmed = text.trim() || "Deferred agent produced no final text.";
  return `${trimmed}\n\nArtifacts:\n- Brief: ${briefPath}\n- Result: ${resultPath}\n- Transcript: ${transcriptPath}\n- Status: ${statusPath}`;
}

export default function deferExtension(pi: ExtensionAPI) {
  if (process.env.PI_DEFER_AGENT === "1") {
    return;
  }

  pi.registerTool({
    name: "defer_task",
    label: "Defer Task",
    description: "Run a bounded task in an isolated deferred pi subagent. Use for research, planning, review, or implementation work that should not pollute the main context. Artifacts are written under the project's .pi/defer directory.",
    parameters: Type.Object({
      task: Type.String({ description: "The complete bounded task for the deferred agent." }),
      role: Type.Optional(Type.String({ description: "Optional role/instructions label, e.g. researcher, planner, implementer, reviewer." })),
      accessMode: Type.Optional(Type.Union([
        Type.Literal("readonly"),
        Type.Literal("write"),
      ], { description: "Deferred agent access mode. Defaults to readonly." })),
      model: Type.Optional(Type.String({ description: "Optional pi --model value for the deferred agent." })),
      timeoutSeconds: Type.Optional(Type.Number({ description: "Optional timeout in seconds. Defaults to 1800." })),
    }),
    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      const accessMode = (params.accessMode ?? "readonly") as AccessMode;
      if (!ACCESS_MODES.includes(accessMode)) {
        throw new Error(`Invalid accessMode: ${String(params.accessMode)}`);
      }

      const runId = `${new Date().toISOString().replace(/[:.]/g, "-")}-${randomUUID().slice(0, 8)}`;
      const deferRoot = resolve(ctx.cwd, ".pi", "defer");
      const runDir = join(deferRoot, runId);
      mkdirSync(runDir, { recursive: true });

      const briefPath = join(runDir, "brief.md");
      const transcriptPath = join(runDir, "transcript.jsonl");
      const resultPath = join(runDir, "result.md");
      const statusPath = join(runDir, "status.json");

      writeFileSync(briefPath, params.task, "utf8");
      writeFileSync(statusPath, JSON.stringify({ status: "running", runId, accessMode, role: params.role ?? null, startedAt: new Date().toISOString() }, null, 2), "utf8");

      const binary = process.env.PI_BINARY || "pi";
      const argv = [binary, "--mode", "rpc", "--no-session"];
      if (params.model) {
        argv.push("--model", params.model);
      }

      const transcript = (event: RpcEvent) => {
        writeFileSync(transcriptPath, `${JSON.stringify({ timestamp: new Date().toISOString(), event })}\n`, { flag: "a" });
      };

      const childEnv: NodeJS.ProcessEnv = {
        ...process.env,
        PI_DEFER_AGENT: "1",
        PI_DEFER_ACCESS_MODE: accessMode,
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
        onUpdate?.({ content: [{ type: "text", text: `Deferred agent ${runId} started (${accessMode}).` }] });
        const agentEnd = child.waitForAgentEnd();
        const promptResponse = await child.send({ type: "prompt", message: deferPrompt({ task: params.task, role: params.role, accessMode, briefPath }) });
        assertSuccess(promptResponse, "deferred prompt");
        await agentEnd;
        const lastAssistant = await child.send({ type: "get_last_assistant_text" });
        assertSuccess(lastAssistant, "get deferred result");
        const resultText = textFromLastAssistantResponse(lastAssistant) ?? "";
        writeFileSync(resultPath, resultText, "utf8");
        writeFileSync(statusPath, JSON.stringify({ status: "done", runId, accessMode, role: params.role ?? null, completedAt: new Date().toISOString(), briefPath, resultPath, transcriptPath }, null, 2), "utf8");
        return {
          content: [{ type: "text", text: resultSummary(resultText, resultPath, transcriptPath, briefPath, statusPath) }],
          details: { runId, runDir, briefPath, resultPath, transcriptPath, statusPath, accessMode },
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        writeFileSync(resultPath, `Deferred agent failed: ${message}\n`, "utf8");
        writeFileSync(statusPath, JSON.stringify({ status: "error", runId, accessMode, role: params.role ?? null, error: message, completedAt: new Date().toISOString(), briefPath, resultPath, transcriptPath }, null, 2), "utf8");
        return {
          content: [{ type: "text", text: `Deferred agent failed: ${message}\n\nArtifacts:\n- Brief: ${briefPath}\n- Result: ${resultPath}\n- Transcript: ${transcriptPath}\n- Status: ${statusPath}` }],
          isError: true,
          details: { runId, runDir, briefPath, resultPath, transcriptPath, statusPath, accessMode, error: message },
        };
      } finally {
        clearTimeout(timeout);
        signal?.removeEventListener("abort", abort);
        child.dispose();
      }
    },
  });
}

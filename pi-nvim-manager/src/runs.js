"use strict";

const childProcess = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { createLineSplitter, parseJsonLine } = require("./protocol");

const EVENT_LIMIT = 1000;
const STDERR_LIMIT = 100;
const ATTACH_STALE_MS = 30_000;

function randomId(prefix) {
  return `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

function defaultAgentDir() {
  const candidate = path.join(os.homedir(), "dotfiles", "pi", "agent");
  return fs.existsSync(candidate) ? candidate : undefined;
}

function normalizeRun(run) {
  return {
    runId: run.runId,
    cwd: run.cwd,
    sessionFile: run.sessionFile,
    sessionName: run.sessionName,
    createdAt: run.createdAt,
    updatedAt: run.updatedAt,
    status: run.status,
    exitCode: run.exitCode,
    isStreaming: run.isStreaming,
    attached: Boolean(run.attachedSocket && !run.attachedSocket.destroyed),
    attachedClientId: run.attachedClientId,
    stale: run.attachedClientId ? Date.now() - run.lastHeartbeat > ATTACH_STALE_MS : false,
    model: run.model,
    messageCount: run.messageCount,
    stderr: run.stderr.slice(-10),
  };
}

class RunManager {
  constructor() {
    this.runs = new Map();
  }

  listRuns() {
    return Array.from(this.runs.values())
      .map((run) => normalizeRun(run))
      .sort((a, b) => b.updatedAt - a.updatedAt);
  }

  get(runId) {
    return this.runs.get(runId);
  }

  spawn(options = {}) {
    const cwd = path.resolve(options.cwd || process.cwd());
    const runId = randomId("run");
    const args = ["--mode", "rpc"];
    if (options.sessionPath) args.push("--session", options.sessionPath);
    if (options.provider) args.push("--provider", options.provider);
    if (options.model) args.push("--model", options.model);
    if (options.sessionDir) args.push("--session-dir", options.sessionDir);

    const env = { ...process.env };
    const agentDir = options.agentDir || defaultAgentDir();
    if (agentDir) env.PI_CODING_AGENT_DIR = agentDir;

    const child = childProcess.spawn(options.binary || "pi", args, {
      cwd,
      env,
      stdio: ["pipe", "pipe", "pipe"],
    });

    const now = Date.now();
    const run = {
      runId,
      child,
      cwd,
      sessionFile: options.sessionPath,
      sessionName: undefined,
      createdAt: now,
      updatedAt: now,
      status: "running",
      exitCode: undefined,
      isStreaming: false,
      attachedSocket: null,
      attachedClientId: undefined,
      lastHeartbeat: 0,
      model: undefined,
      messageCount: 0,
      events: [],
      stderr: [],
    };
    this.runs.set(runId, run);

    child.stdout.on("data", createLineSplitter((line) => this.handleChildLine(run, line)));
    child.stderr.on("data", createLineSplitter((line) => this.handleChildStderr(run, line)));
    child.on("error", (err) => {
      run.status = "error";
      run.updatedAt = Date.now();
      this.pushStderr(run, err.message);
    });
    child.on("exit", (code) => {
      run.status = "exited";
      run.exitCode = code;
      run.isStreaming = false;
      run.updatedAt = Date.now();
      if (run.attachedSocket && !run.attachedSocket.destroyed) {
        run.attachedSocket.write(JSON.stringify({ type: "manager_run_exit", runId, code }) + "\n");
      }
      run.attachedSocket = null;
      run.attachedClientId = undefined;
    });

    return normalizeRun(run);
  }

  handleChildStderr(run, line) {
    this.pushStderr(run, line);
    run.updatedAt = Date.now();
  }

  pushStderr(run, line) {
    if (!line) return;
    run.stderr.push(line);
    if (run.stderr.length > STDERR_LIMIT) run.stderr.shift();
  }

  handleChildLine(run, line) {
    run.updatedAt = Date.now();
    const event = parseJsonLine(line);
    if (event) this.updateMetadataFromEvent(run, event);

    run.events.push({ cursor: `${run.updatedAt}-${run.events.length}`, line, event });
    if (run.events.length > EVENT_LIMIT) run.events.shift();

    if (run.attachedSocket && !run.attachedSocket.destroyed) {
      run.attachedSocket.write(line + "\n");
    }
  }

  updateMetadataFromEvent(run, event) {
    if (event.type === "response" && event.command === "get_state" && event.success && event.data) {
      this.applyState(run, event.data);
    } else if (event.type === "response" && event.command === "get_session_stats" && event.success && event.data) {
      run.messageCount = event.data.totalMessages || run.messageCount;
      run.sessionFile = event.data.sessionFile || run.sessionFile;
    } else if (event.type === "message_start" || event.type === "agent_start") {
      run.isStreaming = true;
    } else if (event.type === "agent_settled" || event.type === "agent_end") {
      run.isStreaming = false;
    }
  }

  applyState(run, data) {
    run.sessionFile = data.sessionFile || run.sessionFile;
    run.sessionName = data.sessionName || run.sessionName;
    run.messageCount = data.messageCount || run.messageCount;
    run.isStreaming = Boolean(data.isStreaming);
    if (data.model) run.model = data.model;
  }

  attach(runId, socket, clientId) {
    const run = this.runs.get(runId);
    if (!run) throw new Error("run not found");
    if (run.status !== "running") throw new Error(`run is ${run.status}`);

    const stale = run.attachedClientId && Date.now() - run.lastHeartbeat > ATTACH_STALE_MS;
    if (run.attachedSocket && !run.attachedSocket.destroyed && !stale) {
      throw new Error("run already attached");
    }

    if (run.attachedSocket && !run.attachedSocket.destroyed && stale) {
      run.attachedSocket.destroy();
    }

    run.attachedSocket = socket;
    run.attachedClientId = clientId;
    run.lastHeartbeat = Date.now();
    run.updatedAt = Date.now();

    return {
      run: normalizeRun(run),
      events: run.events.map((item) => item.event).filter(Boolean),
    };
  }

  detachSocket(socket) {
    for (const run of this.runs.values()) {
      if (run.attachedSocket === socket) {
        run.attachedSocket = null;
        run.attachedClientId = undefined;
        run.lastHeartbeat = 0;
        run.updatedAt = Date.now();
      }
    }
  }

  detach(runId, socket) {
    const run = runId ? this.runs.get(runId) : this.findAttached(socket);
    if (!run) return undefined;
    if (run.attachedSocket && run.attachedSocket !== socket) {
      throw new Error("run is attached to another client");
    }
    run.attachedSocket = null;
    run.attachedClientId = undefined;
    run.lastHeartbeat = 0;
    run.updatedAt = Date.now();
    return normalizeRun(run);
  }

  heartbeat(runId, clientId) {
    const run = this.runs.get(runId);
    if (!run) throw new Error("run not found");
    if (run.attachedClientId !== clientId) throw new Error("client is not attached to run");
    run.lastHeartbeat = Date.now();
    return normalizeRun(run);
  }

  kill(runId, socket) {
    const run = runId ? this.runs.get(runId) : this.findAttached(socket);
    if (!run) throw new Error("run not found");
    const stale = run.attachedClientId && Date.now() - run.lastHeartbeat > ATTACH_STALE_MS;
    if (run.attachedSocket && run.attachedSocket !== socket && !stale) {
      throw new Error("run is attached to another client");
    }
    if (run.child && run.status === "running") run.child.kill();
    run.status = "killed";
    run.updatedAt = Date.now();
    run.attachedSocket = null;
    run.attachedClientId = undefined;
    const result = normalizeRun(run);
    this.runs.delete(run.runId);
    return result;
  }

  findAttached(socket) {
    for (const run of this.runs.values()) {
      if (run.attachedSocket === socket) return run;
    }
    return undefined;
  }

  forwardToAttached(socket, line) {
    const run = this.findAttached(socket);
    if (!run) throw new Error("no run attached");
    if (!run.child || run.status !== "running") throw new Error(`run is ${run.status}`);
    run.child.stdin.write(line + "\n");
  }
}

module.exports = {
  RunManager,
};

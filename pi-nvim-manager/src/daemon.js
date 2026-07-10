"use strict";

const net = require("node:net");
const os = require("node:os");
const { completeFiles, listDir } = require("./fs");
const { listSessions } = require("./sessions");
const { RunManager } = require("./runs");
const {
  createLineSplitter,
  errorResponse,
  parseJsonLine,
  response,
  sendJson,
} = require("./protocol");

const VERSION = "0.1.0";

class Daemon {
  constructor(socketPath) {
    this.socketPath = socketPath;
    this.runs = new RunManager();
  }

  listen() {
    this.server = net.createServer((socket) => this.handleSocket(socket));
    return new Promise((resolve, reject) => {
      this.server.on("error", reject);
      this.server.listen(this.socketPath, () => {
        this.server.off("error", reject);
        resolve();
      });
    });
  }

  handleSocket(socket) {
    socket.setEncoding("utf8");
    socket.on("data", createLineSplitter((line) => {
      this.handleLine(socket, line).catch((err) => {
        sendJson(socket, errorResponse("manager_unknown", {}, err));
      });
    }));
    socket.on("close", () => {
      this.runs.detachSocket(socket);
    });
    socket.on("error", () => {
      this.runs.detachSocket(socket);
    });
  }

  async handleLine(socket, line) {
    const msg = parseJsonLine(line);
    if (!msg || typeof msg !== "object") {
      sendJson(socket, errorResponse("parse", {}, "Bad JSON"));
      return;
    }

    if (typeof msg.type === "string" && msg.type.startsWith("manager_")) {
      await this.handleManagerCommand(socket, msg);
      return;
    }

    try {
      this.runs.forwardToAttached(socket, line);
    } catch (err) {
      const command = msg.type || "pi";
      sendJson(socket, errorResponse(command, msg, err));
    }
  }

  async handleManagerCommand(socket, msg) {
    const command = msg.type;
    try {
      let data;
      switch (command) {
        case "manager_ping":
          data = { version: VERSION, pid: process.pid, host: os.hostname() };
          break;
        case "manager_list_runs":
          data = { runs: this.runs.listRuns() };
          break;
        case "manager_list_sessions":
          data = { sessions: await listSessions() };
          break;
        case "manager_spawn":
          data = { run: this.runs.spawn(msg) };
          break;
        case "manager_attach":
          data = this.runs.attach(msg.runId, socket, msg.clientId || "unknown-client");
          break;
        case "manager_detach":
          data = { run: this.runs.detach(msg.runId, socket) };
          break;
        case "manager_kill":
          data = { run: this.runs.kill(msg.runId, socket) };
          break;
        case "manager_heartbeat":
          data = { run: this.runs.heartbeat(msg.runId, msg.clientId) };
          break;
        case "manager_list_dir":
          data = await listDir(msg.path);
          break;
        case "manager_complete_files":
          data = await completeFiles(msg.cwd, msg.prefix || "");
          break;
        default:
          throw new Error(`unknown manager command: ${command}`);
      }
      sendJson(socket, response(command, msg, data));
      if (command === "manager_attach" && data && Array.isArray(data.events)) {
        setImmediate(() => {
          for (const event of data.events) {
            sendJson(socket, event);
          }
        });
      }
    } catch (err) {
      sendJson(socket, errorResponse(command, msg, err));
    }
  }
}

module.exports = {
  Daemon,
};

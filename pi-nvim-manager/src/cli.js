"use strict";

const childProcess = require("node:child_process");
const fs = require("node:fs");
const fsp = require("node:fs/promises");
const net = require("node:net");
const os = require("node:os");
const path = require("node:path");
const { Daemon } = require("./daemon");

function cacheDir() {
  return process.env.XDG_CACHE_HOME
    ? path.join(process.env.XDG_CACHE_HOME, "pi-nvim-manager")
    : path.join(os.homedir(), ".cache", "pi-nvim-manager");
}

function stateDir() {
  return process.env.XDG_STATE_HOME
    ? path.join(process.env.XDG_STATE_HOME, "pi-nvim-manager")
    : path.join(os.homedir(), ".local", "state", "pi-nvim-manager");
}

function socketPath() {
  return path.join(cacheDir(), "daemon.sock");
}

async function ensureDirs() {
  await fsp.mkdir(cacheDir(), { recursive: true });
  await fsp.mkdir(stateDir(), { recursive: true });
}

function connectSocket(sock, timeoutMs = 1000) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection(sock);
    const timer = setTimeout(() => {
      socket.destroy();
      reject(new Error("timed out connecting to pi-nvim-manager daemon"));
    }, timeoutMs);
    socket.once("connect", () => {
      clearTimeout(timer);
      resolve(socket);
    });
    socket.once("error", (err) => {
      clearTimeout(timer);
      reject(err);
    });
  });
}

async function startDaemon() {
  const entry = process.argv[1];
  const child = childProcess.spawn(process.execPath, [entry, "--daemon"], {
    detached: true,
    stdio: "ignore",
    env: process.env,
  });
  child.unref();
}

async function ensureDaemon(sock) {
  try {
    return await connectSocket(sock, 300);
  } catch (_err) {
    try {
      await fsp.rm(sock, { force: true });
    } catch (_rmErr) {
      // Ignore stale socket removal failures; start attempt below will surface real errors.
    }
    await startDaemon();
    let lastErr;
    for (let i = 0; i < 30; i += 1) {
      await new Promise((resolve) => setTimeout(resolve, 100));
      try {
        return await connectSocket(sock, 300);
      } catch (err) {
        lastErr = err;
      }
    }
    throw lastErr || new Error("could not start pi-nvim-manager daemon");
  }
}

async function runDaemon() {
  await ensureDirs();
  const sock = socketPath();
  try {
    await fsp.rm(sock, { force: true });
  } catch (_err) {
    // Ignore.
  }
  const daemon = new Daemon(sock);
  await daemon.listen();
  process.on("SIGTERM", () => process.exit(0));
  process.on("SIGINT", () => process.exit(0));
}

async function runStdio() {
  await ensureDirs();
  const socket = await ensureDaemon(socketPath());
  process.stdin.pipe(socket);
  socket.pipe(process.stdout);
  process.stdin.resume();
  socket.on("close", () => process.exit(0));
}

async function main() {
  const arg = process.argv[2] || "--stdio";
  if (arg === "--daemon") {
    await runDaemon();
  } else if (arg === "--stdio") {
    await runStdio();
  } else if (arg === "--socket-path") {
    console.log(socketPath());
  } else {
    throw new Error(`unknown argument: ${arg}`);
  }
}

module.exports = {
  main,
};

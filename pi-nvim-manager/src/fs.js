"use strict";

const childProcess = require("node:child_process");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");

const IGNORED_DIRS = new Set([
  ".git",
  ".venv",
  "venv",
  "node_modules",
  "__pycache__",
  ".mypy_cache",
  ".pytest_cache",
  ".ruff_cache",
  ".tox",
  "dist",
  "build",
  "target",
  ".next",
  ".turbo",
  ".cache",
]);

const completeCache = new Map();
const COMPLETE_TTL_MS = 60_000;
const MAX_FILES = 5000;

function expandHome(input) {
  if (!input || input === "~") return os.homedir();
  if (input.startsWith("~/")) return path.join(os.homedir(), input.slice(2));
  return input;
}

async function pathExists(p) {
  try {
    await fs.access(p);
    return true;
  } catch (_err) {
    return false;
  }
}

async function listDir(inputPath) {
  const resolved = path.resolve(expandHome(inputPath || os.homedir()));
  const entries = await fs.readdir(resolved, { withFileTypes: true });
  const dirs = entries
    .filter((entry) => entry.isDirectory() && !IGNORED_DIRS.has(entry.name))
    .map((entry) => ({
      name: entry.name,
      path: path.join(resolved, entry.name),
    }))
    .sort((a, b) => a.name.localeCompare(b.name));

  return {
    path: resolved,
    parent: path.dirname(resolved),
    home: os.homedir(),
    dirs,
  };
}

function collectCommand(cmd, args, opts) {
  return new Promise((resolve, reject) => {
    const child = childProcess.spawn(cmd, args, {
      cwd: opts.cwd,
      env: process.env,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString("utf8");
      if (stdout.length > 2_000_000) child.kill();
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString("utf8");
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0 || stdout) {
        resolve(stdout);
      } else {
        reject(new Error(stderr.trim() || `${cmd} exited with ${code}`));
      }
    });
  });
}

function filterFileList(files) {
  const out = [];
  for (const file of files) {
    if (!file || file === ".") continue;
    const normalized = file.replace(/^\.\//, "");
    const parts = normalized.split(/[\\/]/);
    if (parts.some((part) => IGNORED_DIRS.has(part))) continue;
    out.push(normalized);
    if (out.length >= MAX_FILES) break;
  }
  return out;
}

async function scanFiles(cwd) {
  try {
    const output = await collectCommand("rg", ["--files", "--hidden"], { cwd });
    return filterFileList(output.split(/\r?\n/));
  } catch (_err) {
    const output = await collectCommand("find", [".", "-type", "f"], { cwd });
    return filterFileList(output.split(/\r?\n/));
  }
}

async function completeFiles(inputCwd, prefix) {
  const cwd = path.resolve(expandHome(inputCwd || process.cwd()));
  const now = Date.now();
  let entry = completeCache.get(cwd);
  if (!entry || now - entry.time > COMPLETE_TTL_MS) {
    const promise = scanFiles(cwd);
    entry = { time: now, promise, files: null };
    completeCache.set(cwd, entry);
    entry.files = await promise;
  } else if (!entry.files) {
    entry.files = await entry.promise;
  }

  const needle = prefix || "";
  return {
    cwd,
    files: entry.files.filter((file) => file.startsWith(needle)).slice(0, MAX_FILES),
  };
}

module.exports = {
  completeFiles,
  expandHome,
  listDir,
  pathExists,
};

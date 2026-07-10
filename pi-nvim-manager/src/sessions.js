"use strict";

const fs = require("node:fs");
const fsp = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");

function sessionDirs() {
  return [
    path.join(os.homedir(), ".pi", "agent", "sessions"),
    path.join(os.homedir(), ".pi", "sessions"),
  ];
}

async function walkJsonl(dir, out, limit = 10_000) {
  let entries;
  try {
    entries = await fsp.readdir(dir, { withFileTypes: true });
  } catch (_err) {
    return;
  }
  for (const entry of entries) {
    if (out.length >= limit) return;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      await walkJsonl(full, out, limit);
    } else if (entry.isFile() && entry.name.endsWith(".jsonl")) {
      out.push(full);
    }
  }
}

function fallbackTitle(text) {
  const cleaned = String(text || "")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/^[Hh](ey|i|ello)[,\s:%]*/u, "")
    .replace(/[.?!:;,]+$/u, "");
  if (!cleaned) return undefined;
  return cleaned.length > 64 ? `${cleaned.slice(0, 61).trim()}...` : cleaned;
}

function extractText(message) {
  if (!message || typeof message !== "object") return "";
  const content = message.content;
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === "string") return part;
        if (part && typeof part.text === "string") return part.text;
        return "";
      })
      .join("");
  }
  return "";
}

function parseSessionFile(file) {
  const stat = fs.statSync(file);
  const candidate = {
    path: file,
    mtime: Math.floor(stat.mtimeMs / 1000),
    title: undefined,
    cwd: undefined,
    messageCount: 0,
  };
  let firstUserTitle;
  const text = fs.readFileSync(file, "utf8");
  for (const line of text.split("\n")) {
    if (!line) continue;
    let record;
    try {
      record = JSON.parse(line);
    } catch (_err) {
      continue;
    }
    if (record.type === "session" && typeof record.cwd === "string" && record.cwd) {
      candidate.cwd = record.cwd;
    } else if (record.type === "session_info" && typeof record.name === "string" && record.name.trim()) {
      candidate.title = record.name.trim();
    } else if (record.type === "message") {
      candidate.messageCount += 1;
      if (!firstUserTitle && record.message && record.message.role === "user") {
        firstUserTitle = fallbackTitle(extractText(record.message));
      }
    }
  }
  if (!candidate.title) candidate.title = firstUserTitle || path.basename(file);
  return candidate;
}

async function listSessions() {
  const files = [];
  for (const dir of sessionDirs()) {
    await walkJsonl(dir, files);
  }
  const seen = new Set();
  const sessions = [];
  for (const file of files) {
    const resolved = path.resolve(file);
    if (seen.has(resolved)) continue;
    seen.add(resolved);
    try {
      sessions.push(parseSessionFile(file));
    } catch (_err) {
      // Ignore unreadable or partial session files.
    }
  }
  sessions.sort((a, b) => b.mtime - a.mtime);
  return sessions;
}

module.exports = {
  listSessions,
};

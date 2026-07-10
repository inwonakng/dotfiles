"use strict";

function sendJson(stream, message) {
  stream.write(JSON.stringify(message) + "\n");
}

function response(command, request, data) {
  const out = {
    type: "response",
    command,
    success: true,
  };
  if (request && request.id) out.id = request.id;
  if (data !== undefined) out.data = data;
  return out;
}

function errorResponse(command, request, error) {
  const out = {
    type: "response",
    command,
    success: false,
    error: error && error.message ? error.message : String(error || "unknown error"),
  };
  if (request && request.id) out.id = request.id;
  return out;
}

function createLineSplitter(onLine) {
  let pending = "";
  return (chunk) => {
    pending += chunk.toString("utf8");
    const parts = pending.split("\n");
    pending = parts.pop() || "";
    for (let line of parts) {
      if (line.endsWith("\r")) line = line.slice(0, -1);
      if (line !== "") onLine(line);
    }
  };
}

function parseJsonLine(line) {
  try {
    return JSON.parse(line);
  } catch (_err) {
    return undefined;
  }
}

module.exports = {
  createLineSplitter,
  errorResponse,
  parseJsonLine,
  response,
  sendJson,
};

import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { existsSync, mkdirSync, readFileSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

export type SavedCommand = {
  command: string;
  cwd: string;
  note: string;
  savedAt: string;
};

type CommandStore = { remembered: SavedCommand[]; trusted: SavedCommand[] };
const STORE_PATH = join(getAgentDir(), "bash-access.json");

function readStore(): CommandStore {
  if (!existsSync(STORE_PATH)) {
    return { remembered: [], trusted: [] };
  }
  const value: unknown = JSON.parse(readFileSync(STORE_PATH, "utf8"));
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Invalid bash access store");
  }
  const store = value as Record<string, unknown>;
  if (![store.remembered, store.trusted].every((list) => Array.isArray(list) && list.every(
    (item) => item && typeof item === "object" && !Array.isArray(item)
      && typeof item.command === "string" && typeof item.cwd === "string"
      && typeof item.note === "string" && typeof item.savedAt === "string",
  ))) {
    throw new Error("Invalid bash access store entries");
  }
  return { remembered: store.remembered as SavedCommand[], trusted: store.trusted as SavedCommand[] };
}

function saveStore(store: CommandStore): void {
  mkdirSync(dirname(STORE_PATH), { recursive: true });
  const temporary = `${STORE_PATH}.${process.pid}.tmp`;
  try {
    writeFileSync(temporary, `${JSON.stringify(store, null, 2)}\n`, { flag: "wx", mode: 0o600 });
    renameSync(temporary, STORE_PATH);
  } catch (error) {
    try {
      if (existsSync(temporary)) unlinkSync(temporary);
    } catch {
      // Keep the original write error.
    }
    throw error;
  }
}

export function isTrustedCommand(command: string, cwd: string): boolean {
  return readStore().trusted.some((entry) => entry.command === command && entry.cwd === cwd);
}

export function savedCommands(): CommandStore {
  return readStore();
}

export function rememberCommand(command: string, cwd: string, note: string): void {
  const store = readStore();
  store.remembered = store.remembered.filter((entry) => entry.command !== command || entry.cwd !== cwd);
  store.remembered.push({ command, cwd, note, savedAt: new Date().toISOString() });
  saveStore(store);
}

export function reviewCommand(entry: SavedCommand, action: "trust" | "forget" | "revoke"): void {
  const store = readStore();
  const list = action === "revoke" ? store.trusted : store.remembered;
  const index = list.findIndex((item) => item.command === entry.command && item.cwd === entry.cwd);
  if (index < 0) throw new Error("Saved command no longer exists");
  const [saved] = list.splice(index, 1);
  if (action === "trust") {
    store.trusted = store.trusted.filter((item) => item.command !== saved.command || item.cwd !== saved.cwd);
    store.trusted.push(saved);
  }
  saveStore(store);
}

// Deliberately accept only simple shell words. Shell operators, expansion,
// substitutions, escapes and multiline commands all require approval.
function words(command: string): string[] | undefined {
  if (!command || /[^\w\s./@%:,=+*?'"-]/.test(command) || /[\r\n\t]/.test(command)) {
    return undefined;
  }
  const result: string[] = [];
  let word = "";
  let quote: "'" | '"' | undefined;
  let started = false;
  for (const char of command) {
    if (char === "'" || char === '"') {
      if (!quote) {
        quote = char;
        started = true;
      } else if (quote === char) {
        quote = undefined;
      } else {
        word += char;
      }
    } else if (char === " " && !quote) {
      if (started) {
        result.push(word);
        word = "";
        started = false;
      }
    } else {
      // Unquoted globs can expand into option-looking filenames before the tool runs.
      if (!quote && (char === "*" || char === "?")) return undefined;
      word += char;
      started = true;
    }
  }
  if (quote) return undefined;
  if (started) result.push(word);
  return result.length ? result : undefined;
}

function pathsOnly(args: string[]): boolean {
  let paths = false;
  for (const arg of args) {
    if (arg === "--" && !paths) { paths = true; continue; }
    if (!paths && arg.startsWith("-") && arg !== "-") return false;
  }
  return true;
}

function rgArgs(args: string[]): boolean {
  let files = false;
  let pattern = false;
  let options = true;
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (options && arg === "--") { options = false; continue; }
    if (options && arg === "--files") { files = true; continue; }
    if (options && ["-n", "--line-number", "-i", "--ignore-case", "-l", "--files-with-matches", "-F", "--fixed-strings", "-S", "--smart-case", "-v", "--invert-match", "-w", "--word-regexp", "--hidden"].includes(arg)) continue;
    if (options && ["-g", "--glob"].includes(arg)) {
      if (!args[++i] || args[i].startsWith("-")) return false;
      continue;
    }
    if (options && arg.startsWith("-") && arg !== "-") return false;
    if (!files && !pattern) pattern = true;
  }
  return files || pattern;
}

function gitArgs(args: string[]): boolean {
  const [subcommand, ...rest] = args;
  // Other git subcommands can refresh the index or run configured helpers.
  const flags: Record<string, string[]> = {
    "rev-parse": ["--show-toplevel", "--is-inside-work-tree", "--verify"],
    "ls-files": ["--cached", "--others", "--exclude-standard"],
  };
  const acceptedFlags = flags[subcommand];
  if (!acceptedFlags) return false;
  let afterSeparator = false;
  for (const arg of rest) {
    if (arg === "--" && !afterSeparator) { afterSeparator = true; continue; }
    if (!afterSeparator && arg.startsWith("-") && !acceptedFlags.includes(arg)) return false;
  }
  return true;
}

export function readonlyBashBlockReason(command: string): string | undefined {
  const args = words(command);
  if (!args) return "not a simple read-only command";
  const [program, ...rest] = args;
  if (program === "pwd" && rest.length === 0) return undefined;
  if (program === "ls" && rest.every((arg) => /^-[alhRdt1FG]+$/.test(arg) || !arg.startsWith("-") || arg === "--")) return undefined;
  if (program === "cat" && pathsOnly(rest)) return undefined;
  if (program === "rg" && rgArgs(rest)) return undefined;
  if (program === "git" && gitArgs(rest)) return undefined;
  return "not a recognized read-only command form";
}

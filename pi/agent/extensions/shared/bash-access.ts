import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { existsSync, mkdirSync, readFileSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

export type SavedCommand = {
  command: string;
  cwd: string;
  note: string;
  savedAt: string;
};

type CommandStore = { remembered: SavedCommand[] };
const STORE_PATH = join(getAgentDir(), "bash-access.json");

function readStore(): CommandStore {
  if (!existsSync(STORE_PATH)) {
    return { remembered: [] };
  }
  const value: unknown = JSON.parse(readFileSync(STORE_PATH, "utf8"));
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Invalid bash access store");
  }
  const store = value as Record<string, unknown>;
  if (!Array.isArray(store.remembered) || !store.remembered.every(
    (item) => item && typeof item === "object" && !Array.isArray(item)
      && typeof item.command === "string" && typeof item.cwd === "string"
      && typeof item.note === "string" && typeof item.savedAt === "string",
  )) {
    throw new Error("Invalid bash access store entries");
  }
  return { remembered: store.remembered as SavedCommand[] };
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

export function rememberCommand(command: string, cwd: string, note: string): void {
  const store = readStore();
  store.remembered = store.remembered.filter((entry) => entry.command !== command || entry.cwd !== cwd);
  store.remembered.push({ command, cwd, note, savedAt: new Date().toISOString() });
  saveStore(store);
}

type Word = { kind: "word"; value: string; expanded: boolean };
type Token = Word | { kind: "operator"; value: ";" | "|" | "||" | "2>/dev/null" };

// Only shell syntax explicitly checked below may reach bash. In particular,
// quoting can protect regex punctuation, but substitutions and escapes cannot.
function tokens(command: string): Token[] | undefined {
  if (!command || /[\r\n\t\0]/.test(command)) return undefined;
  const result: Token[] = [];
  let word = "";
  let started = false;
  let expanded = false;
  let quoted = false;
  let quote: "'" | '"' | undefined;
  const flush = () => {
    if (!started) return true;
    if (expanded && quoted) return false;
    result.push({ kind: "word", value: word, expanded });
    word = "";
    started = expanded = quoted = false;
    return true;
  };
  for (let i = 0; i < command.length; i++) {
    const char = command[i];
    if (quote) {
      if (char === quote) {
        quote = undefined;
      } else {
        if (quote === '"' && (char === "$" || char === "`" || char === "\\")) return undefined;
        word += char;
      }
    } else if (char === "'" || char === '"') {
      quote = char;
      quoted = started = true;
    } else if (char === " ") {
      if (!flush()) return undefined;
    } else if (char === ";" || char === "|") {
      if (!flush()) return undefined;
      const operator = char === "|" && command[i + 1] === "|" ? "||" : char;
      if (operator === "||") i++;
      result.push({ kind: "operator", value: operator });
    } else if (!started && command.startsWith("2>/dev/null", i)
      && (i + 11 === command.length || /[ ;|]/.test(command[i + 11]))) {
      result.push({ kind: "operator", value: "2>/dev/null" });
      i += 10;
    } else if (/[A-Za-z0-9_./@%:,=+-]/.test(char) || char === "*" || char === "{" || char === "}") {
      if (char === "*" || char === "{" || char === "}") expanded = true;
      word += char;
      started = true;
    } else {
      return undefined;
    }
  }
  if (quote || !flush()) return undefined;
  return result.length ? result : undefined;
}

// Only scoped path expansion is allowed, never a glob that could turn into an
// option or expand a pattern/flag argument. Quoted globs are literal strings.
function pathWord(word: Word): boolean {
  if (!word.expanded) return true;
  return /^(?:[A-Za-z0-9_.-]+\/)+[A-Za-z0-9_.-]+\*$/.test(word.value)
    || /^(?:[A-Za-z0-9_.-]+\/)+\{[A-Za-z0-9_.-]+(?:,[A-Za-z0-9_.-]+)+\}$/.test(word.value);
}

function pathsOnly(args: string[]): boolean {
  let paths = false;
  for (const arg of args) {
    if (arg === "--" && !paths) { paths = true; continue; }
    if (!paths && arg.startsWith("-") && arg !== "-") return false;
  }
  return true;
}

function rgArgs(args: Word[]): boolean {
  let files = false;
  let pattern = false;
  let options = true;
  for (let i = 0; i < args.length; i++) {
    const { value: arg, expanded } = args[i];
    if (options && arg === "--" && !expanded) { options = false; continue; }
    if (options && arg === "--files" && !expanded) { files = true; continue; }
    if (options && !expanded && ["-n", "--line-number", "-i", "--ignore-case", "-l", "--files-with-matches", "-F", "--fixed-strings", "-S", "--smart-case", "-v", "--invert-match", "-w", "--word-regexp", "--hidden"].includes(arg)) continue;
    if (options && !expanded && ["-g", "--glob"].includes(arg)) {
      if (!args[++i] || args[i].expanded || args[i].value.startsWith("-")) return false;
      continue;
    }
    if (options && arg.startsWith("-") && arg !== "-") return false;
    if (!files && !pattern) {
      if (expanded) return false;
      pattern = true;
    } else if (!pathWord(args[i])) return false;
  }
  return files || pattern;
}

function gitArgs(args: string[]): boolean {
  const [subcommand, ...rest] = args;
  // status reports working-tree state; it may update Git's index cache.
  const flags: Record<string, string[]> = {
    "rev-parse": ["--show-toplevel", "--is-inside-work-tree", "--verify"],
    "ls-files": ["--cached", "--others", "--exclude-standard"],
    "status": [
      "-v", "--verbose", "--no-verbose", "-s", "--short", "--no-short",
      "-b", "--branch", "--no-branch", "--show-stash", "--no-show-stash",
      "--ahead-behind", "--no-ahead-behind", "--porcelain", "--no-porcelain",
      "--long", "--no-long", "-z", "--null", "--no-null", "-u",
      "--untracked-files", "--no-untracked-files", "--ignored", "--no-ignored",
      "--ignore-submodules", "--no-ignore-submodules", "--column", "--no-column",
      "--no-renames", "--renames", "-M", "--find-renames", "--no-find-renames",
    ],
  };
  const acceptedFlags = flags[subcommand];
  if (!acceptedFlags) return false;
  let afterSeparator = false;
  for (const arg of rest) {
    if (arg === "--" && !afterSeparator) { afterSeparator = true; continue; }
    if (!afterSeparator && arg.startsWith("-")) {
      if (acceptedFlags.includes(arg)) continue;
      if (subcommand === "status" && (/^--porcelain=v[12]$/.test(arg)
        || /^--untracked-files=(all|normal|no)$/.test(arg)
        || /^--ignored=(traditional|matching|no)$/.test(arg)
        || /^--ignore-submodules=(all|dirty|untracked|none)$/.test(arg)
        || /^(?:-M|--find-renames=)[0-9]+%?$/.test(arg))) continue;
      return false;
    }
  }
  return true;
}

function findArgs(args: string[]): boolean {
  let i = 0;
  while (i < args.length && !args[i].startsWith("-")) i++;
  if (!i) return false;
  while (i < args.length) {
    const flag = args[i++];
    const value = args[i++];
    if (!value || (flag === "-maxdepth" && !/^[0-9]{1,3}$/.test(value))
      || (flag === "-type" && !["f", "d", "l"].includes(value))
      || (flag === "-name" && value.startsWith("-"))
      || !["-maxdepth", "-type", "-name"].includes(flag)) return false;
  }
  return true;
}

function simple(tokens: Token[]): boolean {
  if (tokens.some((token) => token.kind !== "word" && token.value !== "2>/dev/null")) return false;
  const redirect = tokens.at(-1)?.value === "2>/dev/null";
  const parts = redirect ? tokens.slice(0, -1) : tokens;
  if (!parts.length || parts.some((token) => token.kind !== "word")) return false;
  const [program, ...args] = parts as Word[];
  if (program.expanded || args.some((arg) => arg.expanded && program.value !== "rg")) return false;
  const rest = args.map((arg) => arg.value);
  if (redirect) return program.value === "find" && findArgs(rest);
  if (program.value === "pwd") return rest.length === 0;
  if (program.value === "ls") return rest.every((arg) => /^-[alhRdt1FG]+$/.test(arg) || !arg.startsWith("-") || arg === "--");
  if (program.value === "cat") return pathsOnly(rest);
  if (program.value === "rg") return rgArgs(args);
  if (program.value === "git") return gitArgs(rest);
  if (program.value === "find") return findArgs(rest);
  if (program.value === "which") return rest.length === 1 && /^[A-Za-z0-9_.+-]+$/.test(rest[0]);
  return false;
}

function inspection(tokens: Token[]): boolean {
  const conditional = tokens.findIndex((token) => token.value === "||" && token.kind === "operator");
  if (conditional !== -1) {
    const left = tokens.slice(0, conditional);
    const right = tokens.slice(conditional + 1);
    return left[0]?.value === "which" && simple(left)
      && right.length === 1 && right[0].kind === "word" && right[0].value === "true";
  }
  const pipe = tokens.findIndex((token) => token.value === "|" && token.kind === "operator");
  if (pipe !== -1) {
    const left = tokens.slice(0, pipe);
    const right = tokens.slice(pipe + 1);
    return simple(left) && right.length === 2 && right[0].kind === "word"
      && right[0].value === "head" && right[1].kind === "word"
      && /^-[1-9][0-9]{0,3}$/.test(right[1].value) && Number(right[1].value.slice(1)) <= 1000;
  }
  return simple(tokens);
}

export function readonlyBashBlockReason(command: string): string | undefined {
  const parsed = tokens(command);
  if (!parsed) return "not a simple read-only command";
  let start = 0;
  for (let i = 0; i <= parsed.length; i++) {
    if (i === parsed.length || (parsed[i].kind === "operator" && parsed[i].value === ";")) {
      if (!inspection(parsed.slice(start, i))) return "not a recognized read-only command form";
      start = i + 1;
    }
  }
  return undefined;
}

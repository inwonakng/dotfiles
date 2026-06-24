import type { ExtensionAPI, ExtensionCommandContext, SessionEntry } from "@earendil-works/pi-coding-agent";
import { getAgentDir, withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import { spawnSync } from "child_process";
import { existsSync, mkdirSync, readFileSync, unlinkSync, writeFileSync } from "fs";
import { appendFile } from "fs/promises";
import { dirname, join, relative, resolve, sep } from "path";
import { createHash } from "crypto";

type SnapshotState = { kind: "missing" } | { kind: "blob"; blob: string };

type FileRecord = {
	path: string;
	before: SnapshotState;
	after: SnapshotState;
};

type TurnRecord = {
	version: 1;
	sessionFile: string | undefined;
	baseEntryId: string | null;
	timestamp: string;
	files: FileRecord[];
};

type FileState = {
	before: SnapshotState;
	after?: SnapshotState;
};

type TurnState = {
	baseEntryId: string | null;
	cwd: string;
	gitRoot?: string;
	dirtyAtStart: Set<string>;
	files: Map<string, FileState>;
};

const HISTORY_DIR = join(getAgentDir(), "history");
const SNAPSHOT_GIT_DIR = join(HISTORY_DIR, "objects.git");

let turn: TurnState | undefined;

function assertOk(value: unknown, message: string): asserts value {
	if (!value) {
		throw new Error(message);
	}
}

function markHistoryChanged(ctx: ExtensionCommandContext) {
	ctx.ui.setStatus("pi-history-changed", new Date().toISOString());
}

function runGit(args: string[], options: { cwd?: string; input?: Buffer; binary?: boolean } = {}) {
	const result = spawnSync("git", args, {
		cwd: options.cwd,
		input: options.input,
		encoding: options.binary || options.input ? undefined : "utf-8",
	});
	if (result.status !== 0) {
		const stderr = Buffer.isBuffer(result.stderr) ? result.stderr.toString("utf-8") : result.stderr;
		throw new Error(`git ${args.join(" ")} failed: ${stderr || result.error?.message || "unknown error"}`);
	}
	return result.stdout;
}

function ensureSnapshotStore() {
	mkdirSync(HISTORY_DIR, { recursive: true });
	if (!existsSync(SNAPSHOT_GIT_DIR)) {
		runGit(["init", "--bare", SNAPSHOT_GIT_DIR]);
	}
}

function hashSessionFile(sessionFile: string | undefined) {
	const value = sessionFile || "ephemeral";
	return createHash("sha256").update(value).digest("hex").slice(0, 24);
}

function historyFile(sessionFile: string | undefined) {
	mkdirSync(HISTORY_DIR, { recursive: true });
	return join(HISTORY_DIR, `${hashSessionFile(sessionFile)}.jsonl`);
}

function pathInside(parent: string, child: string) {
	const rel = relative(parent, child);
	return rel === "" || (!rel.startsWith("..") && !rel.startsWith(sep));
}

function normalizePath(cwd: string, path: string) {
	const absolutePath = resolve(cwd, path);
	assertOk(pathInside(cwd, absolutePath), `Refusing to snapshot outside cwd: ${path}`);
	return relative(cwd, absolutePath) || ".";
}

function absolutePath(cwd: string, path: string) {
	const resolvedPath = resolve(cwd, path);
	assertOk(pathInside(cwd, resolvedPath), `Refusing to restore outside cwd: ${path}`);
	return resolvedPath;
}

function normalizeGitPath(cwd: string, gitRoot: string | undefined, path: string) {
	const resolvedPath = resolve(gitRoot || cwd, path);
	if (!pathInside(cwd, resolvedPath)) {
		return undefined;
	}
	return relative(cwd, resolvedPath) || ".";
}

function getGitRoot(cwd: string) {
	const result = spawnSync("git", ["rev-parse", "--show-toplevel"], {
		cwd,
		encoding: "utf-8",
	});
	if (result.status !== 0) {
		return undefined;
	}
	return result.stdout.trim() || undefined;
}

function parseGitStatus(output: string) {
	const paths = new Set<string>();
	const parts = output.split("\0").filter((part) => part.length > 0);
	for (let index = 0; index < parts.length; index++) {
		const part = parts[index];
		const status = part.slice(0, 2);
		const path = part.slice(3);
		if (status.includes("R") || status.includes("C")) {
			index++;
			const nextPath = parts[index];
			if (nextPath) {
				paths.add(nextPath);
			}
		}
		if (path) {
			paths.add(path);
		}
	}
	return paths;
}

function gitStatusPaths(gitRoot: string | undefined) {
	if (!gitRoot) {
		return new Set<string>();
	}
	const output = runGit(["status", "--porcelain=v1", "-z", "--untracked-files=all"], { cwd: gitRoot });
	return parseGitStatus(String(output));
}

function snapshotCurrentFile(cwd: string, path: string): SnapshotState {
	ensureSnapshotStore();
	const filePath = absolutePath(cwd, path);
	if (!existsSync(filePath)) {
		return { kind: "missing" };
	}
	const output = runGit(["--git-dir", SNAPSHOT_GIT_DIR, "hash-object", "-w", filePath]);
	return { kind: "blob", blob: String(output).trim() };
}

function snapshotGitHead(gitRoot: string | undefined, cwd: string, path: string): SnapshotState {
	if (!gitRoot) {
		return { kind: "missing" };
	}
	const absolute = absolutePath(cwd, path);
	const repoPath = relative(gitRoot, absolute);
	const result = spawnSync("git", ["show", `HEAD:${repoPath}`], {
		cwd: gitRoot,
		encoding: undefined,
	});
	if (result.status !== 0) {
		return { kind: "missing" };
	}
	ensureSnapshotStore();
	const blob = runGit(["--git-dir", SNAPSHOT_GIT_DIR, "hash-object", "-w", "--stdin"], {
		input: result.stdout,
	});
	return { kind: "blob", blob: String(blob).trim() };
}

function sameState(left: SnapshotState, right: SnapshotState) {
	return left.kind === right.kind && (left.kind === "missing" || left.blob === (right as { blob: string }).blob);
}

function snapshotBefore(path: string) {
	assertOk(turn, "No active turn");
	const normalizedPath = normalizePath(turn.cwd, path);
	if (!turn.files.has(normalizedPath)) {
		turn.files.set(normalizedPath, {
			before: snapshotCurrentFile(turn.cwd, normalizedPath),
		});
	}
}

function snapshotAfter(path: string) {
	assertOk(turn, "No active turn");
	const normalizedPath = normalizePath(turn.cwd, path);
	const current = turn.files.get(normalizedPath) || {
		before: snapshotCurrentFile(turn.cwd, normalizedPath),
	};
	current.after = snapshotCurrentFile(turn.cwd, normalizedPath);
	turn.files.set(normalizedPath, current);
}

function recordGitChanges() {
	if (!turn) {
		return;
	}
	const dirtyNow = gitStatusPaths(turn.gitRoot);
	for (const path of dirtyNow) {
		const normalizedPath = normalizeGitPath(turn.cwd, turn.gitRoot, path);
		if (!normalizedPath) {
			continue;
		}
		if (!turn.files.has(normalizedPath)) {
			turn.files.set(normalizedPath, {
				before: turn.dirtyAtStart.has(path)
					? snapshotCurrentFile(turn.cwd, normalizedPath)
					: snapshotGitHead(turn.gitRoot, turn.cwd, normalizedPath),
			});
		}
		snapshotAfter(normalizedPath);
	}
}

async function appendRecord(sessionFile: string | undefined, record: TurnRecord) {
	const path = historyFile(sessionFile);
	await withFileMutationQueue(path, async () => {
		await appendFile(path, `${JSON.stringify(record)}\n`, "utf-8");
	});
}

function readRecords(sessionFile: string | undefined) {
	const path = historyFile(sessionFile);
	if (!existsSync(path)) {
		return [] as TurnRecord[];
	}
	return readFileSync(path, "utf-8")
		.split("\n")
		.filter((line) => line.trim() !== "")
		.map((line) => JSON.parse(line) as TurnRecord);
}

function messageText(entry: SessionEntry) {
	if (entry.type !== "message" || entry.message.role !== "user") {
		return "";
	}
	const content = entry.message.content;
	if (typeof content === "string") {
		return content;
	}
	return content
		.filter((item) => item.type === "text")
		.map((item) => item.text)
		.join("");
}

function shortText(text: string) {
	const firstLine = text.trim().split(/\r?\n/, 1)[0] || "(empty)";
	return firstLine.length > 80 ? `${firstLine.slice(0, 77)}...` : firstLine;
}

function branchIdsAfter(entries: SessionEntry[], targetId: string | null) {
	const ids = new Set<string>();
	const targetIndex = targetId ? entries.findIndex((entry) => entry.id === targetId) : -1;
	assertOk(!targetId || targetIndex >= 0, `Could not find target entry: ${targetId}`);
	const startIndex = targetId ? targetIndex + 1 : 0;
	for (const entry of entries.slice(startIndex)) {
		ids.add(entry.id);
	}
	return ids;
}

function restoreBlob(blob: string, path: string) {
	const output = runGit(["--git-dir", SNAPSHOT_GIT_DIR, "cat-file", "-p", blob], { binary: true });
	mkdirSync(dirname(path), { recursive: true });
	writeFileSync(path, output);
}

function restoreState(cwd: string, path: string, state: SnapshotState) {
	const filePath = absolutePath(cwd, path);
	if (state.kind === "missing") {
		if (existsSync(filePath)) {
			unlinkSync(filePath);
		}
		return;
	}
	restoreBlob(state.blob, filePath);
}

function restorePlan(records: TurnRecord[]) {
	const planned = new Map<string, FileRecord>();
	for (const record of records) {
		for (const file of record.files) {
			const existing = planned.get(file.path);
			planned.set(file.path, {
				path: file.path,
				before: existing ? existing.before : file.before,
				after: file.after,
			});
		}
	}
	return Array.from(planned.values());
}

function validateCurrentState(cwd: string, files: FileRecord[]) {
	const conflicts = [];
	for (const file of files) {
		const current = snapshotCurrentFile(cwd, file.path);
		if (!sameState(current, file.after)) {
			conflicts.push(file.path);
		}
	}
	return conflicts;
}

async function revertAfter(ctx: ExtensionCommandContext, targetId: string | null) {
	const sessionFile = ctx.sessionManager.getSessionFile();
	const branch = ctx.sessionManager.getBranch();
	const afterIds = branchIdsAfter(branch, targetId);
	const records = readRecords(sessionFile).filter((record) => {
		return record.baseEntryId !== null && afterIds.has(record.baseEntryId);
	});
	const files = restorePlan(records);
	if (files.length === 0) {
		ctx.ui.notify("No recorded file changes to revert.", "info");
		return true;
	}
	const conflicts = validateCurrentState(ctx.cwd, files);
	if (conflicts.length > 0) {
		ctx.ui.notify(`Rollback blocked; files changed since the agent turn:\n${conflicts.join("\n")}`, "error");
		return false;
	}
	const confirmed = await ctx.ui.confirm("Revert recorded file changes?", `${files.length} file(s) will be restored.`);
	if (!confirmed) {
		return false;
	}
	for (const file of files) {
		restoreState(ctx.cwd, file.path, file.before);
	}
	ctx.ui.notify(`Reverted ${files.length} file(s).`, "info");
	return true;
}

async function pickUserMessage(ctx: ExtensionCommandContext) {
	const entries = ctx.sessionManager
		.getBranch()
		.filter((entry) => {
			return entry.type === "message" && entry.message.role === "user";
		})
		.reverse();
	if (entries.length === 0) {
		ctx.ui.notify("No user messages in this session.", "warning");
		return undefined;
	}
	const options = entries.map((entry) => `${entry.id}  ${shortText(messageText(entry))}`);
	const choice = await ctx.ui.select("Pi history", options);
	if (!choice) {
		return undefined;
	}
	const id = choice.split(/\s+/, 1)[0];
	return entries.find((entry) => entry.id === id);
}

export default function historyExtension(pi: ExtensionAPI) {
	pi.on("turn_start", (_event, ctx) => {
		const gitRoot = getGitRoot(ctx.cwd);
		turn = {
			baseEntryId: ctx.sessionManager.getLeafId(),
			cwd: ctx.cwd,
			gitRoot,
			dirtyAtStart: gitStatusPaths(gitRoot),
			files: new Map(),
		};
		for (const path of turn.dirtyAtStart) {
			const normalizedPath = normalizeGitPath(ctx.cwd, gitRoot, path);
			if (!normalizedPath) {
				continue;
			}
			snapshotBefore(normalizedPath);
		}
	});

	pi.on("tool_call", (event) => {
		if (!turn) {
			return undefined;
		}
		if ((event.toolName === "edit" || event.toolName === "write") && typeof event.input.path === "string") {
			snapshotBefore(event.input.path);
		}
		return undefined;
	});

	pi.on("tool_result", (event) => {
		if (!turn || event.isError) {
			return undefined;
		}
		if ((event.toolName === "edit" || event.toolName === "write") && typeof event.input.path === "string") {
			snapshotAfter(event.input.path);
		}
		return undefined;
	});

	pi.on("turn_end", async (_event, ctx) => {
		if (!turn) {
			return;
		}
		recordGitChanges();
		const files: FileRecord[] = [];
		for (const [path, state] of turn.files) {
			const after = state.after || snapshotCurrentFile(turn.cwd, path);
			if (!sameState(state.before, after)) {
				files.push({ path, before: state.before, after });
			}
		}
		if (files.length > 0) {
			await appendRecord(ctx.sessionManager.getSessionFile(), {
				version: 1,
				sessionFile: ctx.sessionManager.getSessionFile(),
				baseEntryId: turn.baseEntryId,
				timestamp: new Date().toISOString(),
				files,
			});
		}
		turn = undefined;
	});

	pi.registerCommand("pi-history", {
		description: "Pick an earlier user message and fork or revert to it",
		handler: async (_args, ctx) => {
			const entry = await pickUserMessage(ctx);
			if (!entry) {
				return;
			}
			const action = await ctx.ui.select("History action", ["Revert", "Fork"]);
			if (action === "Fork") {
				const text = messageText(entry);
				await ctx.fork(entry.id, {
					position: "before",
					withSession: async (newCtx) => {
						newCtx.ui.setEditorText(text);
						markHistoryChanged(newCtx);
					},
				});
			} else if (action === "Revert") {
				const reverted = await revertAfter(ctx, entry.parentId);
				if (!reverted) {
					return;
				}
				const result = await ctx.navigateTree(entry.id);
				if (result.cancelled) {
					return;
				}
				ctx.ui.setEditorText(messageText(entry));
				markHistoryChanged(ctx);
			}
		},
	});

	pi.registerCommand("pi-revert-after", {
		description: "Revert recorded file changes after an entry id",
		handler: async (args, ctx) => {
			const targetId = args.trim() || null;
			const reverted = await revertAfter(ctx, targetId);
			if (reverted) {
				markHistoryChanged(ctx);
			}
		},
	});

	pi.registerCommand("pi-fork-message", {
		description: "Fork before a user message and prefill it for editing",
		handler: async (args, ctx) => {
			const id = args.trim();
			assertOk(id, "Usage: /pi-fork-message <entry-id>");
			const entry = ctx.sessionManager.getEntry(id);
			assertOk(entry, `Unknown entry: ${id}`);
			const text = messageText(entry);
			await ctx.fork(id, {
				position: "before",
				withSession: async (newCtx) => {
					newCtx.ui.setEditorText(text);
					markHistoryChanged(newCtx);
				},
			});
		},
	});
}

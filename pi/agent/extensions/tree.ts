import { readFileSync, writeFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { locationForEntry, moveToLocation } from "./shared/workspace-navigation";
import { hasRunningSubagents } from "./spawn";

type JsonRecord = Record<string, unknown>;

function parseArgs(args: string) {
	const parts = args.trim().split(/\s+/).filter(Boolean);
	const entryId = parts.find((part) => !part.startsWith("--") && !part.startsWith("-"));
	const summarize = parts.includes("--summary") || parts.includes("-s");
	const yes = parts.includes("--yes") || parts.includes("-y");
	return { entryId, summarize, yes };
}

function contentText(content: unknown): string {
	if (typeof content === "string") {
		return content;
	}
	if (!Array.isArray(content)) {
		return "";
	}
	return content
		.map((item) => {
			if (typeof item === "string") {
				return item;
			}
			if (item && typeof item === "object" && "type" in item && item.type === "text" && "text" in item) {
				return typeof item.text === "string" ? item.text : "";
			}
			return "";
		})
		.join("");
}

function editorTextForTreeEntry(entry: unknown): string | undefined {
	if (!entry || typeof entry !== "object" || !("type" in entry)) {
		return undefined;
	}
	if (entry.type === "message" && "message" in entry) {
		const message = entry.message;
		if (message && typeof message === "object" && "role" in message && message.role === "user" && "content" in message) {
			return contentText(message.content);
		}
	}
	if (entry.type === "custom_message" && "content" in entry) {
		return contentText(entry.content);
	}
	return undefined;
}

function readSessionRecords(sessionFile: string): JsonRecord[] {
	return readFileSync(sessionFile, "utf8")
		.split(/\r?\n/)
		.filter((line) => line.trim() !== "")
		.map((line) => JSON.parse(line) as JsonRecord);
}

function recordId(record: JsonRecord): string | undefined {
	return typeof record.id === "string" ? record.id : undefined;
}

function parentId(record: JsonRecord): string | null | undefined {
	if (record.parentId === null) {
		return null;
	}
	return typeof record.parentId === "string" ? record.parentId : undefined;
}

function collectDeletedIds(records: JsonRecord[], targetId: string): Set<string> {
	const deleted = new Set<string>([targetId]);
	let changed = true;
	while (changed) {
		changed = false;
		for (const record of records) {
			const id = recordId(record);
			const parent = parentId(record);
			if (!id || deleted.has(id) || !parent || !deleted.has(parent)) {
				continue;
			}
			deleted.add(id);
			changed = true;
		}
	}
	return deleted;
}

function shouldDropForDeletedReference(record: JsonRecord, deletedIds: Set<string>): boolean {
	if (record.type === "label" && typeof record.targetId === "string" && deletedIds.has(record.targetId)) {
		return true;
	}
	if (record.type === "branch_summary" && typeof record.fromId === "string" && deletedIds.has(record.fromId)) {
		return true;
	}
	if (record.type === "compaction" && typeof record.firstKeptEntryId === "string" && deletedIds.has(record.firstKeptEntryId)) {
		return true;
	}
	return false;
}

function makeId(existingIds: Set<string>): string {
	for (let attempt = 0; attempt < 100; attempt++) {
		const id = Math.floor(Math.random() * 0xffffffff)
			.toString(16)
			.padStart(8, "0")
			.slice(0, 8);
		if (!existingIds.has(id)) {
			return id;
		}
	}
	throw new Error("Could not allocate unique session entry id");
}

function appendLeafMarker(records: JsonRecord[], leafParentId: string | null): string {
	const existingIds = new Set(records.map(recordId).filter((id): id is string => typeof id === "string"));
	const id = makeId(existingIds);
	records.push({
		type: "custom",
		id,
		parentId: leafParentId,
		timestamp: new Date().toISOString(),
		customType: "pi-tree-delete-leaf",
		data: { reason: "preserve active leaf after subtree deletion" },
	});
	return id;
}

function rewriteSessionWithoutSubtree(sessionFile: string, targetId: string, currentLeafId: string | null) {
	const records = readSessionRecords(sessionFile);
	const target = records.find((record) => recordId(record) === targetId);
	if (!target) {
		throw new Error(`Unknown tree entry: ${targetId}`);
	}
	const deletedIds = collectDeletedIds(records, targetId);
	const targetParentId = parentId(target) ?? null;
	let desiredLeafParentId = currentLeafId && !deletedIds.has(currentLeafId) ? currentLeafId : targetParentId;

	const kept = records.filter((record) => {
		const id = recordId(record);
		if (id && deletedIds.has(id)) {
			return false;
		}
		return !shouldDropForDeletedReference(record, deletedIds);
	});

	const removedCount = records.length - kept.length;
	const keptEntryIds = new Set(kept.map(recordId).filter((id): id is string => typeof id === "string"));
	if (desiredLeafParentId !== null && !keptEntryIds.has(desiredLeafParentId)) {
		desiredLeafParentId = null;
	}
	const lastKeptId = kept.length > 0 ? recordId(kept[kept.length - 1]!) : undefined;
	let markerId: string | undefined;
	if (desiredLeafParentId === null || lastKeptId !== desiredLeafParentId) {
		markerId = appendLeafMarker(kept, desiredLeafParentId);
	}

	writeFileSync(sessionFile, kept.map((record) => JSON.stringify(record)).join("\n") + "\n", "utf8");

	return {
		deletedCount: removedCount,
		desiredLeafId: markerId ?? desiredLeafParentId,
	};
}

export default function treeExtension(pi: ExtensionAPI) {
	pi.registerCommand("pi-tree-jump", {
		description: "Navigate to an entry in the current session tree",
		handler: async (args, ctx) => {
			const { entryId, summarize } = parseArgs(args);
			if (!entryId) {
				ctx.ui.notify("Usage: /pi-tree-jump <entry-id> [--summary]", "error");
				return;
			}

			const entry = ctx.sessionManager.getEntry(entryId);
			if (!entry) {
				ctx.ui.notify(`Unknown tree entry: ${entryId}`, "error");
				return;
			}

			const targetPosition = (entry.type === "message" && entry.message.role === "user")
				|| entry.type === "custom_message" ? entry.parentId : entry.id;
			const location = locationForEntry(ctx, targetPosition);
			if (summarize && location.cwd !== ctx.cwd) {
				ctx.ui.notify("Cross-workspace branch summaries are not supported; jump without summary instead.", "warning");
				return;
			}
			if (summarize) {
				const result = await ctx.navigateTree(entryId, { summarize: true });
				if (result.cancelled) return;
			}
			const moved = await moveToLocation(ctx, location.cwd, ctx.sessionManager.getLeafId(), {
				navigateTo: summarize ? undefined : entryId,
				onArrival: (nextCtx) => {
				const editorText = editorTextForTreeEntry(entry);
				if (editorText !== undefined) nextCtx.ui.setEditorText(editorText);
				nextCtx.ui.setStatus("pi-tree-leaf", nextCtx.sessionManager.getLeafId() ?? "");
				nextCtx.ui.setStatus("pi-history-changed", new Date().toISOString());
				nextCtx.ui.notify(`Tree: moved to ${entryId}${summarize ? " with summary" : ""}.`, "info");
			},
			});
			if (!moved) ctx.ui.notify("Tree navigation was cancelled.", "warning");
		},
	});

	pi.registerCommand("pi-tree-delete", {
		description: "Delete an entry and its descendant subtree from the current session",
		handler: async (args, ctx) => {
			const { entryId, yes } = parseArgs(args);
			if (!entryId) {
				ctx.ui.notify("Usage: /pi-tree-delete <entry-id> [--yes]", "error");
				return;
			}
			if (!ctx.isIdle() || hasRunningSubagents()) {
				ctx.ui.notify("Wait for Pi and its subagents to finish before deleting session history.", "warning");
				return;
			}

			const sessionFile = ctx.sessionManager.getSessionFile();
			if (!sessionFile) {
				ctx.ui.notify("Cannot delete tree entries from an in-memory session.", "error");
				return;
			}

			const records = readSessionRecords(sessionFile);
			const target = records.find((record) => recordId(record) === entryId);
			if (!target) {
				ctx.ui.notify(`Unknown tree entry: ${entryId}`, "error");
				return;
			}
			const deleteCount = collectDeletedIds(records, entryId).size;
			if (!yes) {
				const confirmed = await ctx.ui.confirm(
					"Delete session history?",
					`Delete entry ${entryId} and ${deleteCount - 1} descendant entr${deleteCount === 2 ? "y" : "ies"}?`,
				);
				if (!confirmed) {
					return;
				}
			}

			const currentLeafId = ctx.sessionManager.getLeafId();
			const removedIds = collectDeletedIds(records, entryId);
			const expectedLeaf = currentLeafId && !removedIds.has(currentLeafId) ? currentLeafId : parentId(target) ?? null;
			const location = locationForEntry(ctx, expectedLeaf);
			let result: ReturnType<typeof rewriteSessionWithoutSubtree>;
			try {
				result = rewriteSessionWithoutSubtree(sessionFile, entryId, currentLeafId);
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				ctx.ui.notify(`Could not delete tree entry: ${message}`, "error");
				return;
			}

			const switched = await moveToLocation(ctx, location.cwd, result.desiredLeafId, {
				reload: true,
				onArrival: (nextCtx) => {
					nextCtx.ui.setStatus("pi-tree-leaf", nextCtx.sessionManager.getLeafId() ?? "");
					nextCtx.ui.setStatus("pi-history-changed", new Date().toISOString());
				},
			});
			if (!switched) {
				ctx.ui.notify(
					`Deleted entries, but session reload was cancelled. Restart or resume ${sessionFile} to pick up the change.`,
					"warning",
				);
			}
		},
	});
}

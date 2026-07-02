import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function parseArgs(args: string) {
	const parts = args.trim().split(/\s+/).filter(Boolean);
	const entryId = parts.find((part) => !part.startsWith("--"));
	const summarize = parts.includes("--summary") || parts.includes("-s");
	return { entryId, summarize };
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

			const result = await ctx.navigateTree(entryId, { summarize });
			if (result.cancelled) {
				return;
			}

			const leafId = ctx.sessionManager.getLeafId();
			const editorText = editorTextForTreeEntry(entry);
			if (editorText !== undefined) {
				ctx.ui.setEditorText(editorText);
			}
			ctx.ui.setStatus("pi-tree-leaf", leafId ?? "");
			ctx.ui.setStatus("pi-history-changed", new Date().toISOString());
			ctx.ui.notify(
				`Tree: moved to ${leafId ?? "root"}${summarize ? " with summary" : ""}.`,
				"info",
			);
		},
	});
}

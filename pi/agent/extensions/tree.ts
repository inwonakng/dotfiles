import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function parseArgs(args: string) {
	const parts = args.trim().split(/\s+/).filter(Boolean);
	const entryId = parts.find((part) => !part.startsWith("--"));
	const summarize = parts.includes("--summary") || parts.includes("-s");
	return { entryId, summarize };
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

			ctx.ui.setStatus("pi-tree-leaf", entryId);
			ctx.ui.setStatus("pi-history-changed", new Date().toISOString());
			ctx.ui.notify(`Tree: moved to ${entryId}${summarize ? " with summary" : ""}.`, "info");
		},
	});
}

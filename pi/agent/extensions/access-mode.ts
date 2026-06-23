import type { ExtensionAPI, ExtensionContext, ToolCallEvent } from "@earendil-works/pi-coding-agent";
import { generateUnifiedPatch } from "@earendil-works/pi-coding-agent";
import assert from "assert";
import { existsSync, readFileSync } from "fs";
import { dirname, resolve } from "path";

type AccessMode = "readonly" | "ask" | "review" | "write";

const ACCESS_MODES: AccessMode[] = ["readonly", "ask", "review", "write"];
const READONLY_TOOLS = new Set(["read", "grep", "find", "ls"]);

let accessMode: AccessMode = "readonly";

function parseAccessMode(input: string): AccessMode | undefined {
	const value = input.trim().toLowerCase();
	return ACCESS_MODES.find((mode) => mode === value);
}

function modeDescription(): string {
	if (accessMode === "readonly") {
		return "Only read, grep, find, and ls may run. bash, edit, write, and custom tools are blocked.";
	}
	if (accessMode === "ask") {
		return "read, grep, find, and ls may run. Any other tool requires user approval.";
	}
	if (accessMode === "review") {
		return "read, grep, find, and ls may run. edit and write require diff approval; bash and custom tools require user approval.";
	}
	return "All available tools may run without an access-mode prompt.";
}

function setStatus(ctx: ExtensionContext): void {
	ctx.ui.setStatus("pi-access-mode", `Mode: ${accessMode}`);
}

function toolSummary(event: ToolCallEvent): string {
	const input = event.input as Record<string, unknown>;
	if (event.toolName === "bash" && typeof input.command === "string") {
		return input.command;
	}
	if ((event.toolName === "edit" || event.toolName === "write") && typeof input.path === "string") {
		return input.path;
	}
	return JSON.stringify(input);
}

function jsonPreview(value: unknown): string {
	return JSON.stringify(value, null, 2);
}

function exactEditPreview(cwd: string, input: Record<string, unknown>): string {
	const path = input.path;
	const edits = input.edits;
	if (typeof path !== "string" || !Array.isArray(edits)) {
		return jsonPreview(input);
	}

	const absolutePath = resolve(cwd, path);
	const original = readFileSync(absolutePath, "utf-8");
	const replacements: { index: number; oldText: string; newText: string }[] = [];
	for (const edit of edits) {
		assertEdit(edit);
		const index = original.indexOf(edit.oldText);
		const matches = original.split(edit.oldText).length - 1;
		if (matches !== 1) {
			throw new Error(`Cannot preview edit for ${path}: oldText matched ${matches} times.`);
		}
		replacements.push({ index, oldText: edit.oldText, newText: edit.newText });
	}
	replacements.sort((left, right) => right.index - left.index);
	for (let index = 0; index < replacements.length - 1; index++) {
		const current = replacements[index];
		const next = replacements[index + 1];
		const nextEnd = next.index + next.oldText.length;
		assert(nextEnd <= current.index, `Cannot preview edit for ${path}: edits overlap.`);
	}
	let nextContent = original;
	for (const replacement of replacements) {
		nextContent =
			nextContent.slice(0, replacement.index) +
			replacement.newText +
			nextContent.slice(replacement.index + replacement.oldText.length);
	}
	return generateUnifiedPatch(path, original, nextContent);
}

function writePreview(cwd: string, input: Record<string, unknown>): { text: string; filetype: string } {
	const path = input.path;
	const content = input.content;
	if (typeof path !== "string" || typeof content !== "string") {
		return { text: jsonPreview(input), filetype: "json" };
	}

	const absolutePath = resolve(cwd, path);
	if (!existsSync(absolutePath)) {
		return {
			text: `# New file: ${path}\n# Directory: ${dirname(absolutePath)}\n\n${content}`,
			filetype: "text",
		};
	}
	const original = readFileSync(absolutePath, "utf-8");
	return { text: generateUnifiedPatch(path, original, content), filetype: "diff" };
}

function assertEdit(value: unknown): asserts value is { oldText: string; newText: string } {
	assert(typeof value === "object" && value !== null, "invalid edit object");
	const edit = value as Record<string, unknown>;
	assert(typeof edit.oldText === "string", "edit.oldText must be a string");
	assert(edit.oldText.length > 0, "edit.oldText must not be empty");
	assert(typeof edit.newText === "string", "edit.newText must be a string");
}

function previewForTool(event: ToolCallEvent, ctx: ExtensionContext): { text: string; filetype: string } {
	const input = event.input as Record<string, unknown>;
	if (event.toolName === "bash") {
		return {
			filetype: "sh",
			text: `# cwd: ${ctx.cwd}\n# mode: ${accessMode}\n\n${typeof input.command === "string" ? input.command : jsonPreview(input)}`,
		};
	}
	if (event.toolName === "edit") {
		return { text: exactEditPreview(ctx.cwd, input), filetype: "diff" };
	}
	if (event.toolName === "write") {
		return writePreview(ctx.cwd, input);
	}
	return { text: jsonPreview(input), filetype: "json" };
}

function approvalPayload(event: ToolCallEvent, ctx: ExtensionContext): string {
	const preview = previewForTool(event, ctx);
	return JSON.stringify({
		kind: "pi_approval_preview",
		tool: event.toolName,
		mode: accessMode,
		summary: toolSummary(event),
		preview_filetype: preview.filetype,
		preview: preview.text,
	});
}

export default function accessModeExtension(pi: ExtensionAPI) {
	pi.on("session_start", (event, ctx) => {
		void event;
		setStatus(ctx);
	});

	pi.on("before_agent_start", (event) => {
		return {
			systemPrompt: `${event.systemPrompt}\n\nAccess mode: ${accessMode}. ${modeDescription()}`,
		};
	});

	pi.on("tool_call", async (event, ctx) => {
		setStatus(ctx);

		if (READONLY_TOOLS.has(event.toolName)) {
			return undefined;
		}

		if (accessMode === "write") {
			return undefined;
		}

		if (accessMode === "readonly") {
			return {
				block: true,
				reason: `Tool "${event.toolName}" blocked in readonly mode.`,
			};
		}

		if (!ctx.hasUI) {
			return {
				block: true,
				reason: `Tool "${event.toolName}" requires approval, but no UI is available.`,
			};
		}

		const confirmed = await ctx.ui.confirm(`Allow ${event.toolName}?`, approvalPayload(event, ctx));
		if (!confirmed) {
			return {
				block: true,
				reason: `Tool "${event.toolName}" blocked by user.`,
			};
		}

		return undefined;
	});

	pi.registerCommand("pi-mode", {
		description: "Set access mode: /pi-mode readonly|ask|review|write",
		handler: async (args, ctx) => {
			const requestedMode = parseAccessMode(args);
			if (!requestedMode) {
				ctx.ui.notify("Usage: /pi-mode readonly|ask|review|write", "warning");
				setStatus(ctx);
				return;
			}

			accessMode = requestedMode;
			setStatus(ctx);
			ctx.ui.notify(`Access mode: ${accessMode}`, "info");
		},
	});
}

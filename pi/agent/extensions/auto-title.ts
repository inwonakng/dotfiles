import type { ExtensionAPI, ExtensionContext, InputEvent } from "@earendil-works/pi-coding-agent";

const DEFAULT_TITLE_MODEL = "opencode/north-mini-code-free";
const DEFAULT_TITLE_ENDPOINT = "https://opencode.ai/zen/v1/chat/completions";
const TITLE_LIMIT = 64;

function titleApiKey() {
	return process.env.PI_TITLE_API_KEY || process.env.OPENCODE_ZEN_API_KEY || process.env.OPENCODE_API_KEY;
}

function titleModel() {
	return process.env.PI_TITLE_MODEL || DEFAULT_TITLE_MODEL;
}

function titleEndpoint() {
	return process.env.PI_TITLE_ENDPOINT || DEFAULT_TITLE_ENDPOINT;
}

function apiModelId(model: string) {
	return model.startsWith("opencode/") ? model.slice("opencode/".length) : model;
}

function isTitleCandidate(event: InputEvent, ctx: ExtensionContext) {
	if (event.streamingBehavior) {
		return false;
	}
	const text = event.text.trim();
	if (text === "" || text.startsWith("/") || text.startsWith("!") || text.startsWith("#")) {
		return false;
	}
	if (ctx.sessionManager.getBranch().some((entry) => entry.type === "message" && entry.message.role === "user")) {
		return false;
	}
	return true;
}

function normalizeWhitespace(text: string) {
	return text.replace(/\s+/g, " ").trim();
}

function stripLeadingCommandLanguage(text: string) {
	return text
		.replace(/^(can you|could you|please|pls|hey|hi|hello)[,:\s]+/i, "")
		.replace(/^(implement|create|build|add|fix|debug|review|explain)\s+(me\s+)?/i, "$1 ");
}

function deterministicTitle(text: string) {
	const normalized = stripLeadingCommandLanguage(normalizeWhitespace(text))
		.replace(/[.?!:;,]+$/g, "")
		.trim();
	if (normalized.length <= TITLE_LIMIT) {
		return normalized || "New session";
	}
	return `${normalized.slice(0, TITLE_LIMIT - 3).trimEnd()}...`;
}

function cleanModelTitle(text: string) {
	return normalizeWhitespace(text)
		.replace(/^["'`]+|["'`]+$/g, "")
		.replace(/[.?!:;,]+$/g, "")
		.slice(0, TITLE_LIMIT)
		.trim();
}

async function modelTitle(prompt: string) {
	const apiKey = titleApiKey();
	if (!apiKey) {
		return undefined;
	}

	const response = await fetch(titleEndpoint(), {
		method: "POST",
		headers: {
			authorization: `Bearer ${apiKey}`,
			"content-type": "application/json",
		},
		body: JSON.stringify({
			model: apiModelId(titleModel()),
			messages: [
				{
					role: "system",
					content:
						"Generate a concise session title. Return only the title, no punctuation at the end, no quotes, at most 6 words.",
				},
				{
					role: "user",
					content: prompt.slice(0, 1200),
				},
			],
			max_tokens: 24,
			temperature: 0,
		}),
	});
	if (!response.ok) {
		throw new Error(`title request failed: ${response.status} ${response.statusText}`);
	}

	const data = (await response.json()) as { choices?: { message?: { content?: unknown } }[] };
	const content = data.choices?.[0]?.message?.content;
	if (typeof content !== "string") {
		return undefined;
	}
	return cleanModelTitle(content);
}

function setTitle(pi: ExtensionAPI, ctx: ExtensionContext, title: string) {
	pi.setSessionName(title);
	ctx.ui.setTitle(`Pi - ${title}`);
	ctx.ui.setStatus("pi-session-title", title);
}

export default function autoTitleExtension(pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		const title = pi.getSessionName();
		if (title) {
			ctx.ui.setTitle(`Pi - ${title}`);
			ctx.ui.setStatus("pi-session-title", title);
		}
	});

	pi.on("input", (event, ctx) => {
		if (!isTitleCandidate(event, ctx) || pi.getSessionName()) {
			return undefined;
		}

		const fallback = deterministicTitle(event.text);
		setTitle(pi, ctx, fallback);

		void modelTitle(event.text)
			.then((title) => {
				if (title && title !== fallback && pi.getSessionName() === fallback) {
					setTitle(pi, ctx, title);
				}
			})
			.catch((error: unknown) => {
				const message = error instanceof Error ? error.message : String(error);
				ctx.ui.notify(`Could not generate model session title: ${message}`, "warning");
			});

		return undefined;
	});

	pi.registerCommand("pi-title", {
		description: "Set the current session title: /pi-title <title>",
		handler: async (args, ctx) => {
			const title = cleanModelTitle(args);
			if (!title) {
				ctx.ui.notify("Usage: /pi-title <title>", "warning");
				return;
			}
			setTitle(pi, ctx, title);
		},
	});

	pi.registerCommand("pi-rename", {
		description: "Rename the current session",
		handler: async (args, ctx) => {
			let title = cleanModelTitle(args);
			if (!title) {
				const value = await ctx.ui.input("Rename Session: ", pi.getSessionName() || "");
				title = cleanModelTitle(value || "");
			}
			if (!title) {
				return;
			}
			setTitle(pi, ctx, title);
		},
	});
}

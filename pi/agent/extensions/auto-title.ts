import { AuthStorage, getAgentDir, type ExtensionAPI, type ExtensionContext, type InputEvent } from "@earendil-works/pi-coding-agent";
import { join } from "node:path";

const DEFAULT_TITLE_PROVIDER = "opencode";
const DEFAULT_TITLE_MODEL = "opencode/mimo-v2.5-free";
const DEFAULT_TITLE_ENDPOINT = "https://opencode.ai/zen/v1/chat/completions";
const TITLE_LIMIT = 64;
const MODEL_TITLE_LIMIT = 50;
const TITLE_SYSTEM_PROMPT = [
	"You are a title generator. You output ONLY a thread title. Nothing else.",
	"Generate a brief title that would help the user find this conversation later.",
	"Your output must be a single line, at most 50 characters, no quotes, no explanations.",
	"Use the same language as the user message you are summarizing.",
	"Focus on the main topic or question the user needs to retrieve.",
	"Keep exact technical terms, numbers, filenames, and error codes.",
	"Never include tool names in the title.",
	"Never use tools.",
	"NEVER respond to questions or requests; only generate a title for the conversation.",
	"DO NOT say you cannot generate a title or complain about the input.",
	"Always output something meaningful, even if the input is minimal.",
].join("\n");

let authStorage: ReturnType<typeof AuthStorage.create> | undefined;

function titleProvider() {
	return process.env.PI_TITLE_PROVIDER || DEFAULT_TITLE_PROVIDER;
}

function getAuthStorage() {
	if (!authStorage) {
		authStorage = AuthStorage.create(join(getAgentDir(), "auth.json"));
	}
	return authStorage;
}

async function titleApiKey() {
	const envKey = process.env.PI_TITLE_API_KEY || process.env.OPENCODE_ZEN_API_KEY || process.env.OPENCODE_API_KEY;
	if (envKey) {
		return envKey;
	}
	return getAuthStorage().getApiKey(titleProvider());
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

function cleanTitle(text: string, limit = TITLE_LIMIT) {
	return normalizeWhitespace(text)
		.replace(/^["'`]+|["'`]+$/g, "")
		.replace(/^(title|session title)\s*[:\-]\s*/i, "")
		.replace(/[.?!:;,]+$/g, "")
		.slice(0, limit)
		.trim();
}

function isUsefulModelTitle(title: string) {
	if (!title || title.length > MODEL_TITLE_LIMIT || title.split(/\s+/).length > 8) {
		return false;
	}
	if (/[`{}<>]|<tool_call>|```/i.test(title)) {
		return false;
	}
	if (/\b(i\s+am|i'm|i\s+will|i'll|i\s+can|i\s+cannot|i\s+can't|i\s+don't|let\s+me|sure|sorry)\b/i.test(title)) {
		return false;
	}
	return true;
}

function cleanModelTitle(text: string) {
	const withoutThinking = text.replace(/<think>[\s\S]*?<\/think>/gi, "");
	const firstLine = withoutThinking
		.split("\n")
		.map((line) => cleanTitle(line, MODEL_TITLE_LIMIT))
		.find((line) => line.length > 0);
	if (!firstLine || !isUsefulModelTitle(firstLine)) {
		return undefined;
	}
	return firstLine;
}

function titleUserPrompt(text: string) {
	return `Generate a title for this conversation:\n${text.slice(0, 1200)}`;
}

async function modelTitle(prompt: string) {
	const apiKey = await titleApiKey();
	const headers: Record<string, string> = {
		"content-type": "application/json",
	};
	if (apiKey) {
		headers.authorization = `Bearer ${apiKey}`;
	}

	const response = await fetch(titleEndpoint(), {
		method: "POST",
		headers,
		body: JSON.stringify({
			model: apiModelId(titleModel()),
			messages: [
				{
					role: "system",
					content: TITLE_SYSTEM_PROMPT,
				},
				{
					role: "user",
					content: titleUserPrompt(prompt),
				},
			],
			max_tokens: 40,
			temperature: 0.3,
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
			const title = cleanTitle(args);
			if (!title) {
				ctx.ui.notify("Usage: /pi-title <title>", "warning");
				return;
			}
			setTitle(pi, ctx, title);
		},
	});

	pi.registerCommand("pi-retitle", {
		description: "Regenerate the current session title using the title model",
		handler: async (_args, ctx) => {
			const userMessages = ctx.sessionManager
				.getBranch()
				.filter((entry) => entry.type === "message" && entry.message.role === "user")
				.map((entry) => {
					const content = entry.message.content;
					if (typeof content === "string") {
						return content;
					}
					return content
						.filter((item) => item.type === "text")
						.map((item) => item.text)
						.join("");
				})
				.filter((text) => text.trim() !== "");

			const prompt = userMessages.slice(0, 3).join("\n\n");
			if (!prompt) {
				ctx.ui.notify("No user messages to title.", "warning");
				return;
			}

			const fallback = deterministicTitle(prompt);
			const title = (await modelTitle(prompt)) || fallback;
			setTitle(pi, ctx, title);
		},
	});

	pi.registerCommand("pi-rename", {
		description: "Rename the current session",
		handler: async (args, ctx) => {
			let title = cleanTitle(args);
			if (!title) {
				const value = await ctx.ui.input("Rename Session: ", pi.getSessionName() || "");
				title = cleanTitle(value || "");
			}
			if (!title) {
				return;
			}
			setTitle(pi, ctx, title);
		},
	});
}

import { AuthStorage, getAgentDir, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
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

function isPromptTitleCandidate(text: string) {
	const trimmed = text.trim();
	return trimmed !== "" && !trimmed.startsWith("/") && !trimmed.startsWith("!") && !trimmed.startsWith("#");
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

function messageText(message: unknown) {
	if (!message || typeof message !== "object") {
		return "";
	}
	const content = (message as { content?: unknown }).content;
	if (typeof content === "string") {
		return content;
	}
	if (Array.isArray(content)) {
		return content
			.map((item) => {
				if (typeof item === "string") {
					return item;
				}
				if (item && typeof item === "object" && "type" in item && item.type === "text" && "text" in item) {
					const text = item.text;
					return typeof text === "string" ? text : "";
				}
				return "";
			})
			.join("");
	}
	return "";
}

function branchUserMessages(ctx: ExtensionContext) {
	return ctx.sessionManager
		.getBranch()
		.filter((entry) => entry.type === "message" && entry.message.role === "user")
		.map((entry) => messageText(entry.message))
		.filter((text) => text.trim() !== "");
}

function branchUserMessagesWithEvent(ctx: ExtensionContext, message: unknown) {
	const messages = branchUserMessages(ctx);
	const text = messageText(message);
	if (text.trim() !== "" && !messages.includes(text)) {
		messages.push(text);
	}
	return messages;
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
	let titleGenerationInFlightForSession: string | undefined;

	pi.on("session_start", (_event, ctx) => {
		titleGenerationInFlightForSession = undefined;
		const title = pi.getSessionName();
		if (title) {
			ctx.ui.setTitle(`Pi - ${title}`);
			ctx.ui.setStatus("pi-session-title", title);
		}
	});

	pi.on("message_end", (event, ctx) => {
		if (event.message.role !== "user" || pi.getSessionName()) {
			return undefined;
		}

		const userMessages = branchUserMessagesWithEvent(ctx, event.message);
		if (userMessages.length !== 1 || !isPromptTitleCandidate(userMessages[0])) {
			return undefined;
		}

		const currentSessionKey = () => ctx.sessionManager.getSessionFile() || "ephemeral";
		const sessionKey = currentSessionKey();
		if (titleGenerationInFlightForSession === sessionKey) {
			return undefined;
		}
		titleGenerationInFlightForSession = sessionKey;

		const prompt = userMessages[0];
		ctx.ui.setStatus("pi-session-title", "Generating title…");

		void modelTitle(prompt)
			.then((title) => {
				if (currentSessionKey() !== sessionKey || pi.getSessionName()) {
					return;
				}
				setTitle(pi, ctx, title || deterministicTitle(prompt));
			})
			.catch((error: unknown) => {
				if (currentSessionKey() === sessionKey && !pi.getSessionName()) {
					setTitle(pi, ctx, deterministicTitle(prompt));
				}
				const message = error instanceof Error ? error.message : String(error);
				ctx.ui.notify(`Could not generate model session title: ${message}`, "warning");
			})
			.finally(() => {
				if (titleGenerationInFlightForSession === sessionKey) {
					titleGenerationInFlightForSession = undefined;
				}
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
			const prompt = branchUserMessages(ctx).slice(0, 3).join("\n\n");
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

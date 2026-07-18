import { getAgentDir, readStoredCredential, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { join } from "node:path";

const DEFAULT_TITLE_PROVIDER = "opencode";
// OpenCode normally generates titles with its hidden title agent and the active provider's small model.
// We could mirror that by discovering configured providers and selecting their smallest model, but for now
// keep this extension self-contained by using an anonymously available OpenCode free model.
const DEFAULT_TITLE_MODEL = "opencode/nemotron-3-ultra-free";
const DEFAULT_TITLE_ENDPOINT = "https://opencode.ai/zen/v1/chat/completions";
const TITLE_LIMIT = 80;
const MODEL_TITLE_LIMIT = 80;
const MODEL_TITLE_WORD_LIMIT = 12;
const DEFAULT_TITLE_MAX_TOKENS = 800;
const TITLE_SYSTEM_PROMPT = [
	"You are a title generator. You output ONLY a thread title. Nothing else.",
	"Generate a brief title that would help the user find this conversation later.",
	"Your output must be:",
	"- A single line",
	"- ≤80 characters",
	"- No explanations",
	"- you MUST use the same language as the user message you are summarizing",
	"- Title must be grammatically correct and read naturally",
	"- no word salad",
	"- Never include tool names in the title (e.g. \"read tool\", \"bash tool\", \"edit tool\")",
	"- Focus on the main topic or question the user needs to retrieve",
	"- Vary your phrasing - avoid repetitive patterns like always starting with \"Analyzing\"",
	"- When a file is mentioned, focus on WHAT the user wants to do WITH the file, not just that they shared it",
	"- Keep exact: technical terms, numbers, filenames, HTTP codes",
	"- Remove: the, this, my, a, an",
	"- Never assume tech stack",
	"- Never use tools",
	"- NEVER respond to questions, just generate a title for the conversation",
	"- The title should NEVER include \"summarizing\" or \"generating\" when generating a title",
	"- DO NOT SAY YOU CANNOT GENERATE A TITLE OR COMPLAIN ABOUT THE INPUT",
	"- Always output something meaningful, even if the input is minimal.",
	"- If the user message is short or conversational (e.g. \"hello\", \"lol\", \"what's up\", \"hey\"):",
	"  → create a title that reflects the user's tone or intent (such as Greeting, Quick check-in, Light chat, Intro message, etc.)",
	"\"debug 500 errors in production\" → Debugging production 500 errors",
	"\"refactor user service\" → Refactoring user service",
	"\"why is app.js failing\" → app.js failure investigation",
	"\"implement rate limiting\" → Rate limiting implementation",
	"\"how do I connect postgres to my API\" → Postgres API connection",
	"\"best practices for React hooks\" → React hooks best practices",
	"\"@src/auth.ts can you add refresh token support\" → Auth refresh token support",
	"\"@utils/parser.ts this is broken\" → Parser bug fix",
	"\"look at @config.json\" → Config review",
	"\"@App.tsx add dark mode toggle\" → Dark mode toggle in App",
].join("\n");

function titleProvider() {
	return process.env.PI_TITLE_PROVIDER || DEFAULT_TITLE_PROVIDER;
}

function resolveStoredApiKeyValue(key: string, env?: Record<string, string>) {
	const trimmed = key.trim();
	if (!trimmed || trimmed.startsWith("!")) {
		return undefined;
	}

	const envMatch = trimmed.match(/^\$(?:\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))$/);
	if (envMatch) {
		const name = envMatch[1] || envMatch[2];
		return env?.[name] || process.env[name];
	}

	return key;
}

async function titleApiKey(ctx?: ExtensionContext) {
	const envKey = process.env.PI_TITLE_API_KEY || process.env.OPENCODE_ZEN_API_KEY || process.env.OPENCODE_API_KEY;
	if (envKey) {
		return envKey;
	}

	try {
		const registryKey = await ctx?.modelRegistry.getApiKeyForProvider(titleProvider());
		if (registryKey) {
			return registryKey;
		}
	} catch {
		// Fall through to a best-effort direct auth.json read.
	}

	const credential = readStoredCredential(titleProvider(), join(getAgentDir(), "auth.json"));
	if (credential?.type === "api_key" && typeof credential.key === "string") {
		return resolveStoredApiKeyValue(credential.key, credential.env);
	}
	return undefined;
}

function titleModel() {
	return process.env.PI_TITLE_MODEL || DEFAULT_TITLE_MODEL;
}

function titleEndpoint() {
	return process.env.PI_TITLE_ENDPOINT || DEFAULT_TITLE_ENDPOINT;
}

function titleMaxTokens() {
	const parsed = Number.parseInt(process.env.PI_TITLE_MAX_TOKENS || "", 10);
	return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_TITLE_MAX_TOKENS;
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
		.replace(/^["'`*_]+|["'`*_]+$/g, "")
		.replace(/^(title|session title)\s*[:\-]\s*/i, "")
		.replace(/[.?!:;,]+$/g, "")
		.slice(0, limit)
		.trim();
}

function isUsefulModelTitle(title: string) {
	if (!title || title.length > MODEL_TITLE_LIMIT || title.split(/\s+/).length > MODEL_TITLE_WORD_LIMIT) {
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

function previewText(value: unknown, limit = 160) {
	if (typeof value !== "string") {
		return undefined;
	}
	const normalized = normalizeWhitespace(value);
	if (!normalized) {
		return undefined;
	}
	return normalized.length > limit ? `${normalized.slice(0, limit - 3).trimEnd()}...` : normalized;
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

async function modelTitle(prompt: string, ctx?: ExtensionContext) {
	const apiKey = await titleApiKey(ctx);
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
			max_tokens: titleMaxTokens(),
			temperature: 0.3,
		}),
	});
	if (!response.ok) {
		throw new Error(`title request failed: ${response.status} ${response.statusText}`);
	}

	const data = (await response.json()) as {
		choices?: { finish_reason?: unknown; message?: { content?: unknown; reasoning?: unknown } }[];
	};
	const choice = data.choices?.[0];
	const finishReason = typeof choice?.finish_reason === "string" ? choice.finish_reason : "unknown";
	const content = choice?.message?.content;
	if (typeof content !== "string" || content.trim() === "") {
		const reasoning = previewText(choice?.message?.reasoning);
		throw new Error(
			`title response missing content; finish_reason=${finishReason}${reasoning ? `; reasoning=${reasoning}` : ""}`,
		);
	}

	const title = cleanModelTitle(content);
	if (!title) {
		throw new Error(
			`title response was not a useful title; finish_reason=${finishReason}; content=${previewText(content) || "<empty>"}`,
		);
	}
	return title;
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

		void modelTitle(prompt, ctx)
			.then((title) => {
				if (currentSessionKey() !== sessionKey || pi.getSessionName()) {
					return;
				}
				setTitle(pi, ctx, title);
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
			const title = (await modelTitle(prompt, ctx)) || fallback;
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

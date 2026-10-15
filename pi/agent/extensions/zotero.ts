import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { AutocompleteItem, AutocompleteProvider } from "@earendil-works/pi-tui";

const API = "http://127.0.0.1:23119/api/users/0/";
const KINDS = ["paper", "collection", "tag"] as const;
type Kind = (typeof KINDS)[number];
type Entry = AutocompleteItem & { search: string };
type Cache = { entries?: Entry[]; loaded: number; retry: number; pending?: Promise<Entry[]> };
type RecordData = Record<string, unknown>;

function object(value: unknown): RecordData {
	return value !== null && typeof value === "object" && !Array.isArray(value) ? value as RecordData : {};
}

function text(value: unknown): string {
	return typeof value === "string" ? value.replace(/<[^>]*>/g, "").replace(/[\x00-\x1f\x7f]/g, " ").replace(/\s+/g, " ").trim() : "";
}

function encode(value: string): string {
	return encodeURIComponent(value).replace(/[!'()*]/g, (char) => `%${char.charCodeAt(0).toString(16).toUpperCase()}`);
}

function reference(kind: Kind, label: string, id: string): string {
	// Dot-only path segments are normalized by URL clients; their query form is literal.
	const tagTarget = id === "." || id === ".." ? `${API}items/top?tag=${encode(id)}` : `${API}tags/${encode(id)}`;
	const target = kind === "tag" ? tagTarget
		: `zotero://select/library/${kind === "paper" ? "items" : "collections"}/${id}`;
	return `[Zotero ${kind}: ${label.replace(/[\\[\]]/g, "\\$&")}](${target})`;
}

function entriesFrom(rows: unknown[], kind: Kind): Entry[] {
	const records = rows.map(object);
	const collections = new Map(records.map((row) => [text(row.key), object(row.data)]));
	const entries: Entry[] = [];
	for (const row of records) {
		const data = object(row.data);
		const id = kind === "tag" ? row.tag : row.key;
		if (typeof id !== "string" || (kind !== "tag" && !/^[A-Z0-9]{8}$/.test(id))) continue;
		if (kind === "paper" && ["attachment", "note", "annotation"].includes(String(data.itemType))) continue;
		let label = text(kind === "tag" ? id : kind === "collection" ? data.name : data.title);
		if (!label) continue;
		let description: string = kind;
		let search = label;
		if (kind === "paper") {
			const creators = Array.isArray(data.creators) ? data.creators.map(object) : [];
			const authors = creators.map((creator) => text(creator.name) || [text(creator.firstName), text(creator.lastName)].join(" ")).join(", ");
			const tags = Array.isArray(data.tags) ? data.tags.map((tag) => text(object(tag).tag)).join(" ") : "";
			const year = text(data.date).match(/\b\d{4}\b/)?.[0] ?? "";
			const venue = text(data.journalAbbreviation) || text(data.publicationTitle)
				|| text(data.conferenceName) || text(data.proceedingsTitle);
			const shortNames = creators.map((creator) => text(creator.lastName) || text(creator.name) || text(creator.firstName)).filter(Boolean);
			const byline = (shortNames[0] ?? "") + (shortNames.length > 1 ? " et al." : "");
			description = [year, venue, byline].filter(Boolean).join(" · ");
			search = [label, text(data.shortTitle), text(data.citationKey), authors, year, tags].join(" ");
		} else if (kind === "collection") {
			const seen = new Set([id]);
			let parent = text(data.parentCollection);
			while (parent && !seen.has(parent) && collections.has(parent)) {
				seen.add(parent);
				const ancestor = collections.get(parent)!;
				label = `${text(ancestor.name)} / ${label}`;
				parent = text(ancestor.parentCollection);
			}
			search = label;
		}
		entries.push({ value: reference(kind, label, id), label, description, search: search.toLowerCase() });
	}
	return entries.sort((a, b) => a.label < b.label ? -1 : a.label > b.label ? 1 : 0);
}

// AND across words; contiguous matches rank ahead of subsequence matches.
function score(search: string, query: string): number | undefined {
	let total = 0;
	for (const word of query.toLowerCase().split(/\s+/).filter(Boolean)) {
		const contiguous = search.indexOf(word);
		if (contiguous >= 0) { total += contiguous; continue; }
		let position = -1;
		for (const char of word) {
			position = search.indexOf(char, position + 1);
			if (position < 0) return undefined;
		}
		total += 1000 + position;
	}
	return total;
}

function token(lines: string[], line: number, col: number): string | undefined {
	return (lines[line] ?? "").slice(0, col).match(/(?:^|\s)(@z:[^@\r\n]*)$/)?.[1];
}

export default function zotero(pi: ExtensionAPI): void {
	let shutdown: AbortController | undefined;
	pi.on("session_shutdown", () => shutdown?.abort());
	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		shutdown?.abort();
		const lifetime = new AbortController();
		shutdown = lifetime;
		const caches = new Map<Kind, Cache>();
		let errorShown = false;

		async function load(kind: Kind): Promise<Entry[]> {
			let cache = caches.get(kind);
			if (!cache) { cache = { loaded: 0, retry: 0 }; caches.set(kind, cache); }
			if (cache.pending) return cache.entries ?? cache.pending;
			if (Date.now() < cache.retry || (cache.entries && Date.now() - cache.loaded < 60_000)) return cache.entries ?? [];
			const state = cache;
			const endpoint = kind === "paper" ? "items/top" : kind === "collection" ? "collections" : "tags";
			state.pending = (async () => {
				try {
					const response = await fetch(API + endpoint, {
						headers: { "Zotero-API-Version": "3" }, redirect: "error",
						signal: AbortSignal.any([lifetime.signal, AbortSignal.timeout(3000)]),
					});
					if (!response.ok) throw new Error(`HTTP ${response.status}`);
					const rows: unknown = await response.json();
					if (!Array.isArray(rows)) throw new Error("Expected a Zotero result list");
					state.entries = entriesFrom(rows, kind);
					state.loaded = Date.now();
					errorShown = false;
					ctx.ui.setStatus("zotero", undefined);
				} catch (error) {
					if (!lifetime.signal.aborted) {
						state.retry = Date.now() + 10_000;
						ctx.ui.setStatus("zotero", `Zotero unavailable${state.entries ? " (cached suggestions)" : ""}`);
						if (!errorShown) {
							errorShown = true;
							ctx.ui.notify(`Zotero: ${error instanceof Error ? error.message : "request failed"}. Open Zotero and enable Settings → Advanced → Allow other applications to communicate with Zotero.`, "warning");
						}
					}
				} finally { state.pending = undefined; }
				return state.entries ?? [];
			})();
			return state.entries ?? state.pending;
		}

		ctx.ui.addAutocompleteProvider((current): AutocompleteProvider => ({
			triggerCharacters: [...new Set([...(current.triggerCharacters ?? []), "@", ":"])],
			async getSuggestions(lines, line, col, options) {
				const prefix = token(lines, line, col);
				if (prefix === undefined) return current.getSuggestions(lines, line, col, options);
				const tail = prefix.slice(3);
				const colon = tail.indexOf(":");
				if (colon < 0) {
					const items = KINDS.filter((kind) => kind.startsWith(tail)).map((kind) => ({
						value: `@z:${kind}:`, label: `@z:${kind}:`, description: `Search Zotero ${kind}s`,
					}));
					return items.length ? { items, prefix } : null;
				}
				const kind = tail.slice(0, colon) as Kind;
				if (!KINDS.includes(kind)) return null;
				if (options.signal.aborted || lifetime.signal.aborted) return null;
				// Pi serializes provider calls: release the consumer on cancellation,
				// while letting the shared metadata refresh finish for the next query.
				const entries = await new Promise<Entry[] | undefined>((resolve, reject) => {
					const aborted = () => resolve(undefined);
					options.signal.addEventListener("abort", aborted, { once: true });
					load(kind).then(resolve, reject).finally(() => options.signal.removeEventListener("abort", aborted));
				});
				if (!entries || options.signal.aborted || lifetime.signal.aborted) return null;
				const query = tail.slice(colon + 1).trim();
				const items = entries.map((entry) => ({ entry, score: score(entry.search, query) }))
					.filter((match): match is { entry: Entry; score: number } => match.score !== undefined)
					.sort((a, b) => a.score - b.score).slice(0, 20).map(({ entry }) => entry);
				return items.length ? { items, prefix } : null;
			},
			applyCompletion(lines, line, col, item, prefix) {
				if (!prefix.startsWith("@z:")) return current.applyCompletion(lines, line, col, item, prefix);
				const before = (lines[line] ?? "").slice(0, col - prefix.length);
				const after = (lines[line] ?? "").slice(col);
				const value = item.value + (item.value.startsWith("@z:") || /^\s/.test(after) ? "" : " ");
				const result = [...lines];
				result[line] = before + value + after;
				return { lines: result, cursorLine: line, cursorCol: before.length + value.length };
			},
			shouldTriggerFileCompletion(lines, line, col) {
				return token(lines, line, col) !== undefined || (current.shouldTriggerFileCompletion?.(lines, line, col) ?? true);
			},
		}));
	});
}

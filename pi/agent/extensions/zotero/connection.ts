import { lstat, mkdir, open, readFile, rename, unlink } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { setTimeout as pause } from "node:timers/promises";

export const API = "https://api.zotero.org";
// Use the CLI's native credential store so ordinary zotero-cli commands work too.
export const configPath = join(homedir(), ".config", "zotero-mcp", "config.json");
export type Credentials = { apiKey: string; userID: string };
type Config = Record<string, unknown> & { client_env?: Record<string, string> };
let backoffUntil = 0;

function isObject(value: unknown): value is Record<string, unknown> {
	return value !== null && typeof value === "object" && !Array.isArray(value);
}

function code(error: unknown): string | undefined {
	return isObject(error) && typeof error.code === "string" ? error.code : undefined;
}

async function readConfig(privateOnly = false): Promise<Config> {
	let content: string;
	try {
		const info = await lstat(configPath);
		if (!info.isFile() || (process.getuid && info.uid !== process.getuid())) {
			throw new Error("Zotero configuration must be a regular file owned by you, not a symlink.");
		}
		if (privateOnly && process.platform !== "win32" && (info.mode & 0o077) !== 0) {
			throw new Error("Zotero credentials must be owner-only (0600). Run /zotero-login to save them privately.");
		}
		content = await readFile(configPath, "utf8");
	} catch (error) {
		if (code(error) === "ENOENT") return {};
		if (code(error)) throw new Error("Cannot read Zotero configuration. Check its filesystem permissions.");
		throw error;
	}
	let parsed: unknown;
	try { parsed = JSON.parse(content); }
	catch { throw new Error("Invalid Zotero configuration JSON; the existing file has not been changed."); }
	if (!isObject(parsed) || (parsed.client_env !== undefined && (!isObject(parsed.client_env)
		|| Object.values(parsed.client_env).some(value => typeof value !== "string")))) {
		throw new Error("Invalid Zotero configuration: expected an object with string-valued client_env settings.");
	}
	return parsed as Config;
}

async function saveConfig(config: Config, signal?: AbortSignal): Promise<void> {
	signal?.throwIfAborted();
	const directory = dirname(configPath);
	await mkdir(directory, { recursive: true, mode: 0o700 });
	const info = await lstat(directory);
	if (!info.isDirectory() || (process.getuid && info.uid !== process.getuid())) {
		throw new Error("Zotero configuration directory must be owned by you and must not be a symlink.");
	}
	const temporary = join(directory, `.config-${randomUUID()}.tmp`);
	try {
		const file = await open(temporary, "wx", 0o600);
		try { await file.writeFile(JSON.stringify(config, null, 2) + "\n", "utf8"); }
		finally { await file.close(); }
		signal?.throwIfAborted();
		await rename(temporary, configPath);
	} finally {
		await unlink(temporary).catch(error => { if (code(error) !== "ENOENT") throw error; });
	}
}

export async function credentials(): Promise<Credentials> {
	const config = await readConfig(true);
	const env = config.client_env ?? {};
	const get = (name: string): string => process.env[name] ?? env[name] ?? "";
	if (get("ZOTERO_LOCAL").toLowerCase() !== "false" || get("ZOTERO_LIBRARY_TYPE") !== "user") {
		throw new Error("Zotero library access requires web mode for your personal library. Run /zotero-login and remove conflicting ZOTERO_* environment overrides.");
	}
	const apiKey = get("ZOTERO_API_KEY");
	const userID = get("ZOTERO_LIBRARY_ID");
	if (!/^[A-Za-z0-9]+$/.test(apiKey) || !/^[1-9][0-9]*$/.test(userID)) {
		throw new Error("No Zotero web credentials. Run /zotero-login once on this machine.");
	}
	return { apiKey, userID };
}

export async function request(path: string, apiKey: string, signal?: AbortSignal, version?: string): Promise<Response> {
	// Preserve an in-progress paginated load across successful Backoff responses.
	// Consumer cancellation releases completion separately; session/account changes
	// abort this wait and the shared metadata refresh.
	while (Date.now() < backoffUntil) {
		await pause(Math.min(backoffUntil - Date.now(), 60_000), undefined, { signal });
	}
	signal?.throwIfAborted();
	let response: Response;
	try {
		response = await fetch(API + path, {
			headers: {
				"Zotero-API-Version": "3", "Zotero-API-Key": apiKey,
				...(version ? { "If-Modified-Since-Version": version } : {}),
			},
			redirect: "error",
			signal: signal ? AbortSignal.any([signal, AbortSignal.timeout(15_000)]) : AbortSignal.timeout(15_000),
		});
	} catch { throw new Error("Zotero web request failed. Check your network connection and try again."); }
	for (const name of ["Backoff", "Retry-After"]) {
		const value = response.headers.get(name);
		if (!value) continue;
		const until = /^\d+(\.\d+)?$/.test(value) ? Date.now() + Number(value) * 1000 : Date.parse(value);
		if (Number.isFinite(until)) backoffUntil = Math.max(backoffUntil, until);
	}
	if (!response.ok && response.status !== 304) {
		await response.body?.cancel();
		throw new Error(response.status === 403 ? "Zotero rejected the API key or its permissions. Run /zotero-login."
			: `Zotero web API returned HTTP ${response.status}. Try again later.`);
	}
	return response;
}

export async function login(apiKey: string, signal?: AbortSignal): Promise<string> {
	if (!/^[A-Za-z0-9]+$/.test(apiKey) || apiKey.length > 128) throw new Error("Enter only the Zotero API key, without quotes or shell commands.");
	const response = await request("/keys/current", apiKey, signal);
	let info: unknown;
	try { info = await response.json(); }
	catch { throw new Error("Zotero returned invalid key information."); }
	if (!isObject(info) || !Number.isSafeInteger(info.userID) || Number(info.userID) < 1) {
		throw new Error("Zotero did not return a valid user ID.");
	}
	const access = isObject(info.access) && isObject(info.access.user) ? info.access.user : {};
	const missing = ["library", "notes", "files", "write"].filter(permission => access[permission] !== true);
	if (missing.length) throw new Error(`The key needs personal-library permissions: ${missing.join(", ")}. Update it at https://www.zotero.org/settings/keys.`);
	const userID = String(info.userID);
	const settings = {
		ZOTERO_LOCAL: "false", ZOTERO_LIBRARY_TYPE: "user", ZOTERO_LIBRARY_ID: userID,
		ZOTERO_API_KEY: apiKey, ZOTERO_BACKEND: "api", ZOTERO_NO_CLAUDE: "true",
	};
	const conflicts = Object.entries(settings).filter(([name, value]) => process.env[name] !== undefined && process.env[name] !== value).map(([name]) => name);
	if (conflicts.length) throw new Error(`Environment overrides conflict with web login: ${conflicts.join(", ")}. Unset them and restart Pi, then retry.`);
	// Read immediately before merging; never replace malformed or unrelated settings.
	signal?.throwIfAborted();
	const config = await readConfig();
	config.client_env = { ...config.client_env, ...settings };
	await saveConfig(config, signal);
	return userID;
}

export async function logout(): Promise<void> {
	if (process.env.ZOTERO_API_KEY !== undefined) throw new Error("ZOTERO_API_KEY is set in Pi's environment. Unset it and restart Pi before logging out.");
	const config = await readConfig();
	const env = config.client_env;
	if (!env) return;
	delete env.ZOTERO_API_KEY;
	delete env.ZOTERO_LIBRARY_ID;
	// Keep web mode and disable Claude credential discovery: logout must not
	// silently reconnect to a desktop instance or a different saved API key.
	env.ZOTERO_LOCAL = "false";
	env.ZOTERO_NO_CLAUDE = "true";
	await saveConfig(config);
}

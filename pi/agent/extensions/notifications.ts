import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { spawn, spawnSync } from "node:child_process";
import { basename, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

let enabled = false;
let missingAlerterWarned = false;

const defaultIconPath = resolve(dirname(fileURLToPath(import.meta.url)), "../assets/pi-logo.png");

function setStatus(ctx: ExtensionContext): void {
	ctx.ui.setStatus("pi-notifications", enabled ? "notify on" : "notify off");
}

function alerterPath(): string | undefined {
	const configured = process.env.ALERTER;
	if (configured && existsSync(configured)) {
		return configured;
	}

	for (const candidate of ["/opt/homebrew/bin/alerter", "/usr/local/bin/alerter"]) {
		if (existsSync(candidate)) {
			return candidate;
		}
	}

	const found = spawnSync("/bin/zsh", ["-lc", "command -v alerter"], { encoding: "utf-8" });
	const path = found.stdout?.trim();
	return found.status === 0 && path ? path : undefined;
}

function notificationIconPath(): string | undefined {
	const configured = process.env.PI_NOTIFICATION_ICON;
	if (configured && existsSync(configured)) {
		return configured;
	}
	return existsSync(defaultIconPath) ? defaultIconPath : undefined;
}

function readableCwd(cwd: string, maxLength = 48): string {
	const home = homedir();
	const path = cwd === home ? "~" : cwd.startsWith(`${home}/`) ? `~/${cwd.slice(home.length + 1)}` : cwd;
	if (path.length <= maxLength) {
		return path;
	}

	const prefix = path.startsWith("~/") ? "~" : path.startsWith("/") ? "/" : "";
	const parts = path.split("/").filter(Boolean);
	const finalDir = parts.at(-1) ?? path;
	const shortenedPrefix = prefix === "/" ? "/.../" : prefix ? `${prefix}/.../` : ".../";
	const withFinalDir = `${shortenedPrefix}${finalDir}`;
	if (withFinalDir.length <= maxLength) {
		return withFinalDir;
	}

	const available = Math.max(1, maxLength - shortenedPrefix.length - 3);
	return `${shortenedPrefix}${finalDir.slice(0, available)}...`;
}

function notificationBody(pi: ExtensionAPI, ctx: ExtensionContext): string {
	return `${pi.getSessionName() || basename(ctx.cwd)}\n${readableCwd(ctx.cwd)}`;
}

function notifyPiFinished(pi: ExtensionAPI, ctx: ExtensionContext, force = false): boolean {
	if (!enabled && !force) {
		return false;
	}

	const alerter = alerterPath();
	if (!alerter) {
		if (!missingAlerterWarned) {
			missingAlerterWarned = true;
			ctx.ui.notify("Pi notifications are on, but alerter was not found.", "warning");
		}
		return false;
	}

	const args = ["--title", "Pi finished", "--message", notificationBody(pi, ctx), "--group", "pi-coding-agent"];
	const iconPath = notificationIconPath();
	if (iconPath) {
		args.push("--app-icon", iconPath);
	}

	const child = spawn(alerter, args, {
		detached: true,
		stdio: "ignore",
	});
	child.on("error", (error) => {
		ctx.ui.notify(`Could not send Pi notification: ${error.message}`, "warning");
	});
	child.unref();
	return true;
}

function parseMode(args: string): boolean | undefined {
	const value = args.trim().toLowerCase();
	if (value === "" || value === "toggle") {
		return !enabled;
	}
	if (["on", "yes", "true", "1", "enable", "enabled"].includes(value)) {
		return true;
	}
	if (["off", "no", "false", "0", "disable", "disabled"].includes(value)) {
		return false;
	}
	return undefined;
}

export default function notificationsExtension(pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		setStatus(ctx);
	});

	pi.on("agent_end", (_event, ctx) => {
		notifyPiFinished(pi, ctx);
	});

	pi.registerCommand("pi-notify", {
		description: "Toggle desktop notification on Pi completion: /pi-notify [on|off|toggle|test]",
		handler: async (args, ctx) => {
			if (args.trim().toLowerCase() === "test") {
				if (notifyPiFinished(pi, ctx, true)) {
					ctx.ui.notify("Sent Pi test notification", "info");
				}
				return;
			}

			const next = parseMode(args);
			if (next === undefined) {
				ctx.ui.notify("Usage: /pi-notify [on|off|toggle|test]", "warning");
				return;
			}

			enabled = next;
			setStatus(ctx);
			if (enabled && !alerterPath()) {
				ctx.ui.notify("Pi notifications: on, but alerter was not found", "warning");
			} else {
				ctx.ui.notify(`Pi notifications: ${enabled ? "on" : "off"}`, "info");
			}
		},
	});
}

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { spawn, spawnSync } from "node:child_process";
import { basename } from "node:path";

let enabled = false;
let missingNotifierWarned = false;

function setStatus(ctx: ExtensionContext): void {
	ctx.ui.setStatus("pi-notifications", enabled ? "notify on" : "notify off");
}

function terminalNotifierPath(): string | undefined {
	const configured = process.env.TERMINAL_NOTIFIER;
	if (configured && existsSync(configured)) {
		return configured;
	}

	for (const candidate of [
		"/opt/homebrew/bin/terminal-notifier",
		"/usr/local/bin/terminal-notifier",
		"/Applications/terminal-notifier.app/Contents/MacOS/terminal-notifier",
	]) {
		if (existsSync(candidate)) {
			return candidate;
		}
	}

	const found = spawnSync("/bin/zsh", ["-lc", "command -v terminal-notifier"], { encoding: "utf-8" });
	const path = found.stdout?.trim();
	return found.status === 0 && path ? path : undefined;
}

function notifyPiFinished(pi: ExtensionAPI, ctx: ExtensionContext, force = false): boolean {
	if (!enabled && !force) {
		return false;
	}

	const notifier = terminalNotifierPath();
	if (!notifier) {
		if (!missingNotifierWarned) {
			missingNotifierWarned = true;
			ctx.ui.notify("Pi notifications are on, but terminal-notifier was not found.", "warning");
		}
		return false;
	}

	const sessionName = pi.getSessionName();
	const message = sessionName || basename(ctx.cwd) || "Agent response is ready";
	const child = spawn(
		notifier,
		["-title", "Pi finished", "-message", message, "-group", "pi-coding-agent"],
		{
			detached: true,
			stdio: "ignore",
		},
	);
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
			if (enabled && !terminalNotifierPath()) {
				ctx.ui.notify("Pi notifications: on, but terminal-notifier was not found", "warning");
			} else {
				ctx.ui.notify(`Pi notifications: ${enabled ? "on" : "off"}`, "info");
			}
		},
	});
}

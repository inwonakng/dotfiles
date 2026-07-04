import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
	alerterPath,
	notificationsEnabled,
	parseNotificationMode,
	sendAlerterNotification,
	setNotificationsEnabled,
	toggleNotificationsEnabled,
} from "./shared/notifications";

let missingAlerterWarned = false;

function setStatus(ctx: ExtensionContext): void {
	ctx.ui.setStatus("pi-notifications", notificationsEnabled() ? "notify on" : "notify off");
}

function lastAssistantMessage(messages: unknown[]): { stopReason?: string } | undefined {
	for (let index = messages.length - 1; index >= 0; index--) {
		const message = messages[index];
		if (typeof message === "object" && message !== null && "role" in message && message.role === "assistant") {
			return message as { stopReason?: string };
		}
	}
	return undefined;
}

function notifyPiFinished(pi: ExtensionAPI, ctx: ExtensionContext, force = false): boolean {
	if (!notificationsEnabled() && !force) {
		return false;
	}

	const notified = sendAlerterNotification(pi, ctx, {
		title: "Pi finished",
		group: "pi-coding-agent",
		soundEnv: "PI_COMPLETION_SOUND",
		defaultSound: "Glass",
		timeoutEnv: "PI_COMPLETION_NOTIFICATION_TIMEOUT",
		defaultTimeoutSeconds: 8,
		onError: (error) => {
			ctx.ui.notify(`Could not send Pi notification: ${error.message}`, "warning");
		},
	});
	if (!notified && !missingAlerterWarned) {
		missingAlerterWarned = true;
		ctx.ui.notify("Pi notifications are on, but alerter was not found.", "warning");
	}
	return notified;
}

export default function notificationsExtension(pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		setStatus(ctx);
	});

	pi.on("agent_end", (event, ctx) => {
		const assistant = lastAssistantMessage(event.messages || []);
		if (assistant?.stopReason === "error") {
			return;
		}
		notifyPiFinished(pi, ctx);
	});

	pi.registerCommand("pi-notify", {
		description: "Toggle desktop notifications for Pi completion and permission requests: /pi-notify [on|off|toggle|test]",
		handler: async (args, ctx) => {
			if (args.trim().toLowerCase() === "test") {
				if (notifyPiFinished(pi, ctx, true)) {
					ctx.ui.notify("Sent Pi test notification", "info");
				}
				return;
			}

			const mode = parseNotificationMode(args);
			if (mode === undefined) {
				ctx.ui.notify("Usage: /pi-notify [on|off|toggle|test]", "warning");
				return;
			}

			const enabled = mode === "toggle" ? toggleNotificationsEnabled() : mode;
			if (mode !== "toggle") {
				setNotificationsEnabled(enabled);
			}
			setStatus(ctx);
			if (enabled && !alerterPath()) {
				ctx.ui.notify("Pi notifications: on, but alerter was not found", "warning");
			} else {
				ctx.ui.notify(`Pi notifications: ${enabled ? "on" : "off"}`, "info");
			}
		},
	});
}

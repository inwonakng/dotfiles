#!/usr/bin/env bash
set -euo pipefail

if ! command -v rift-cli >/dev/null 2>&1; then
  exit 127
fi

if ! command -v jq >/dev/null 2>&1; then
  rift-cli execute layout toggle-stack
  exit 0
fi

active_windows="$(rift-cli query windows 2>/dev/null || printf '[]')"
focused_window="$(jq -c 'first(.[] | select(.is_focused == true)) // empty' <<< "$active_windows")"

rift-cli execute layout toggle-stack

if [[ -z "$focused_window" ]]; then
  exit 0
fi

window_id="$(jq -cr '.id' <<< "$focused_window")"
window_server_id="$(jq -r '.window_server_id // empty' <<< "$focused_window")"

if [[ -z "$window_id" || "$window_id" == "null" ]]; then
  exit 0
fi

# Rift raises the newly visible stack windows while toggling. Give that focus/raise
# transaction a moment to finish before restoring the previously focused window.
sleep 0.05

focus_args=(--window-id "$window_id")
if [[ -n "$window_server_id" && "$window_server_id" != "null" ]]; then
  focus_args+=(--window-server-id "$window_server_id")
fi

rift-cli execute window focus "${focus_args[@]}" >/dev/null

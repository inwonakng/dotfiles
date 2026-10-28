#!/usr/bin/env bash
set -euo pipefail

operation="${1:-toggle-stack}"
case "$operation" in
  toggle-stack|toggle-orientation) ;;
  *) printf 'Unsupported layout operation: %s\n' "$operation" >&2; exit 2 ;;
esac

if ! command -v rift-cli >/dev/null 2>&1; then
  exit 127
fi

if ! command -v jq >/dev/null 2>&1; then
  rift-cli execute layout "$operation"
  exit 0
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/rift-window-cache.sh"
rift_load_context
workspace_id="$rift_workspace_id"
focused_window="$(jq -c 'first(.[] | select(.is_focused == true)) // empty' <<< "$rift_windows")"

rift-cli execute layout "$operation"
[[ -z "$focused_window" ]] && exit 0

# Let the layout's raise transaction begin before queueing focus restoration.
sleep 0.05
rift_load_context
[[ "$workspace_id" != "$rift_workspace_id" ]] && exit 0

# The window may have closed or moved while the layout command was running.
window="$(jq -c --argjson previous "$focused_window" \
  'first(.[] | select(.id == $previous.id and .window_server_id == $previous.window_server_id)) // empty' \
  <<< "$rift_windows")"
[[ -z "$window" ]] && exit 0
rift_focus_window "$window" >/dev/null

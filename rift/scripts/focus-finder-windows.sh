#!/usr/bin/env bash
set -euo pipefail

finder_bundle_id="com.apple.finder"

if ! command -v rift-cli >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  open -a Finder
  exit 0
fi

active_windows="$(rift-cli query windows 2>/dev/null || printf '[]')"

focused_finder_window="$(jq -c \
  --arg bundle_id "$finder_bundle_id" \
  '.[] | select(.is_focused and .bundle_id == $bundle_id)' <<< "$active_windows")"

if [[ -n "$focused_finder_window" ]]; then
  other_window="$(jq -c \
    --arg bundle_id "$finder_bundle_id" \
    'first(.[] | select(.bundle_id != $bundle_id)) // empty' <<< "$active_windows")"

  if [[ -n "$other_window" ]]; then
    window_id="$(jq -cr '.id' <<< "$other_window")"
    window_server_id="$(jq -r '.window_server_id' <<< "$other_window")"

    rift-cli execute window focus \
      --window-id "$window_id" \
      --window-server-id "$window_server_id"
  fi

  exit 0
fi

finder_windows="$(jq -c \
  --arg bundle_id "$finder_bundle_id" \
  '.[] | select(.bundle_id == $bundle_id)' <<< "$active_windows")"

if [[ -z "$finder_windows" ]]; then
  osascript \
    -e 'tell application "Finder" to make new Finder window' \
    -e 'tell application "Finder" to activate'
  exit 0
fi

while IFS= read -r window; do
  [[ -z "$window" ]] && continue

  window_id="$(jq -cr '.id' <<< "$window")"
  window_server_id="$(jq -r '.window_server_id' <<< "$window")"
  is_floating="$(jq -r '.is_floating' <<< "$window")"

  if rift-cli execute window focus \
    --window-id "$window_id" \
    --window-server-id "$window_server_id"; then
    if [[ "$is_floating" != "true" ]]; then
      rift-cli execute window toggle-float || true
    fi
  fi
done <<< "$finder_windows"

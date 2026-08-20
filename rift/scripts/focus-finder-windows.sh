#!/usr/bin/env bash
set -euo pipefail

finder_bundle_id="com.apple.finder"

if ! command -v rift-cli >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  open -a Finder
  exit 0
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/rift-window-cache.sh"

rift_load_context

cached_non_finder_window() {
  local cached

  cached="$(rift_cached_window "last_non_finder")"
  [[ -n "$cached" ]] || return 0

  jq -c --argjson cached "$cached" --arg bundle_id "$finder_bundle_id" \
    'first(.[] | select(.id == $cached.id and .bundle_id != $bundle_id)) // empty' \
    <<< "$rift_windows"
}

focused_finder_window="$(jq -c \
  --arg bundle_id "$finder_bundle_id" \
  'first(.[] | select(.is_focused and .bundle_id == $bundle_id)) // empty' <<< "$rift_windows")"

if [[ -n "$focused_finder_window" ]]; then
  other_window="$(cached_non_finder_window)"

  if [[ -z "$other_window" ]]; then
    other_window="$(jq -c \
      --arg bundle_id "$finder_bundle_id" \
      'first(.[] | select(.bundle_id != $bundle_id)) // empty' <<< "$rift_windows")"
  fi

  if [[ -n "$other_window" ]]; then
    rift_focus_window "$other_window"
  fi

  exit 0
fi

focused_non_finder_window="$(jq -c \
  --arg bundle_id "$finder_bundle_id" \
  'first(.[] | select(.is_focused and .bundle_id != $bundle_id)) // empty' <<< "$rift_windows")"
rift_save_cached_window "last_non_finder" "$focused_non_finder_window"

finder_windows="$(jq -c \
  --arg bundle_id "$finder_bundle_id" \
  '.[] | select(.bundle_id == $bundle_id)' <<< "$rift_windows")"

if [[ -z "$finder_windows" ]]; then
  osascript \
    -e 'tell application "Finder" to make new Finder window' \
    -e 'tell application "Finder" to activate'
  exit 0
fi

while IFS= read -r window; do
  [[ -z "$window" ]] && continue

  is_floating="$(jq -r '.is_floating' <<< "$window")"

  if rift_focus_window "$window"; then
    if [[ "$is_floating" != "true" ]]; then
      rift-cli execute window toggle-float || true
    fi
  fi
done <<< "$finder_windows"

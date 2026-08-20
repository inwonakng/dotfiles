#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/rift-window-cache.sh"

rift_load_context

focused_window="$(jq -c 'first(.[] | select(.is_focused == true)) // empty' <<< "$rift_windows")"
focused_is_floating="$(jq -r 'any(.[]; .is_focused == true and .is_floating == true)' <<< "$rift_windows")"

if [[ "$focused_is_floating" == "true" ]]; then
  rift_save_cached_window "last_floating" "$focused_window"
  targets="$(jq -c '.[] | select(.is_floating != true)' <<< "$rift_windows")"
  final_window="$(rift_cached_current_window_where "last_tiled" '.is_floating != true')"
else
  rift_save_cached_window "last_tiled" "$focused_window"
  targets="$(jq -c '.[] | select(.is_floating == true)' <<< "$rift_windows")"
  final_window="$(rift_cached_current_window_where "last_floating" '.is_floating == true')"
fi

[[ -z "$targets" ]] && exit 0

while IFS= read -r window; do
  [[ -z "$window" ]] && continue
  rift_focus_window "$window" >/dev/null
done <<< "$targets"

if [[ -n "$final_window" ]]; then
  rift_focus_window "$final_window" >/dev/null
fi

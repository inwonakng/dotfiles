#!/usr/bin/env bash
set -euo pipefail

windows="$(rift-cli query windows 2>/dev/null || printf '[]')"

focus_window() {
  local window="$1"
  local window_id
  local window_server_id

  window_id="$(jq -cr '.id' <<< "$window")"
  window_server_id="$(jq -r '.window_server_id' <<< "$window")"

  rift-cli execute window focus \
    --window-id "$window_id" \
    --window-server-id "$window_server_id" >/dev/null
}

focused_is_floating="$(
  jq -r 'any(.[]; .is_focused == true and .is_floating == true)' <<< "$windows"
)"

if [[ "$focused_is_floating" == "true" ]]; then
  targets="$(jq -c '.[] | select(.is_floating != true)' <<< "$windows")"
else
  targets="$(jq -c '.[] | select(.is_floating == true)' <<< "$windows")"
fi

[[ -z "$targets" ]] && exit 0

while IFS= read -r window; do
  [[ -z "$window" ]] && continue
  focus_window "$window"
done <<< "$targets"

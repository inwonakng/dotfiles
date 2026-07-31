#!/usr/bin/env bash
set -euo pipefail

finder_bundle_id="com.apple.finder"

if ! command -v aerospace >/dev/null 2>&1; then
  open -a Finder
  exit 0
fi

window_ids="$(aerospace list-windows \
  --workspace focused \
  --app-bundle-id "$finder_bundle_id" \
  --format '%{window-id}' || true)"

if [[ -z "$window_ids" ]]; then
  osascript \
    -e 'tell application "Finder" to make new Finder window' \
    -e 'tell application "Finder" to activate'
  exit 0
fi

while IFS= read -r window_id; do
  [[ -z "$window_id" ]] && continue
  aerospace focus --window-id "$window_id" || true
done <<< "$window_ids"

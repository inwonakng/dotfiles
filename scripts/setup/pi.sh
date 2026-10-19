#!/usr/bin/env bash
# Run with bash after installing Pi and linking the configuration to ~/.pi.
set -euo pipefail

if ! command -v npm >/dev/null 2>&1; then
  printf 'npm is required. Install Node first (bash scripts/setup/node.sh).\n' >&2
  exit 1
fi

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

for manifest in "$repo"/pi/agent/extensions/*/package.json; do
  [[ -f "$manifest" ]] || continue
  extension_dir="${manifest%/package.json}"
  printf 'Installing dependencies: %s\n' "$extension_dir"
  (
    cd -- "$extension_dir"
    npm ci --omit=dev
  )
done

printf 'Extension dependencies installed. Restart Pi or run /reload.\n'

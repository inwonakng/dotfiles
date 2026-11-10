#!/usr/bin/env bash
# Compatibility entry point; Zotero installation logic lives in zotero-tools.
set -euo pipefail
tools="${ZOTERO_TOOLS_DIR:-$HOME/zotero-tools}"
if [[ ! -f "$tools/scripts/install.sh" || ! -f "$tools/pyproject.toml" ]]; then
  printf 'Expected zotero-tools at %s; set ZOTERO_TOOLS_DIR if needed.\n' "$tools" >&2
  exit 1
fi
exec bash "$tools/scripts/install.sh"

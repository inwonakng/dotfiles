#!/usr/bin/env bash
# Run with bash. Does not install plugins or alter the Zotero library.
set -euo pipefail
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
project="$HOME/agents/zotero"

link_file() {
  local source="$1" destination="$2"
  if [[ -e "$destination" && ! -L "$destination" ]]; then
    printf 'Refusing to replace existing file: %s\n' "$destination" >&2
    return 1
  fi
  ln -sfn "$source" "$destination"
}

if ! command -v zip >/dev/null 2>&1; then
  printf 'zip is required to package the Zotero reader bridge.\n' >&2
  exit 1
fi

# Preflight both paths before changing either link.
for destination in "$project/AGENTS.md" "$project/.pi/settings.json"; do
  if [[ -e "$destination" && ! -L "$destination" ]]; then
    printf 'Refusing to replace existing file: %s\n' "$destination" >&2
    exit 1
  fi
done
mkdir -p "$project/.pi"
link_file "$repo/pi/projects/zotero/AGENTS.md" "$project/AGENTS.md"
link_file "$repo/pi/projects/zotero/settings.json" "$project/.pi/settings.json"
xpi="$repo/zotero/pi-zotero-reader.xpi"
mkdir -p "$(dirname -- "$xpi")"
build_dir="$(mktemp -d "$(dirname -- "$xpi")/.build.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
# Build a fresh archive so removed files cannot survive from an earlier version.
(
  cd "$repo/zotero/bridge"
  zip -q "$build_dir/pi-zotero-reader.xpi" manifest.json bootstrap.js
)
mv -f "$build_dir/pi-zotero-reader.xpi" "$xpi"
printf '%s\n' "$xpi"
printf '\nProject linked: %s\nInstall the XPI above in Zotero: Tools > Plugins > gear > Install Plugin From File.\nEnable Zotero Settings > Advanced > Allow other applications to communicate with Zotero.\nThen start a NEW Pi/pi-console session in the project and trust its configuration.\n' "$project"

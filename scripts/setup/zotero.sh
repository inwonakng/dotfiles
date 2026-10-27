#!/usr/bin/env bash
# Run with bash. Wraps the uv-installed CLI; does not alter the Zotero library.
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

if ! command -v uv >/dev/null 2>&1; then
  printf 'uv and its zotero-mcp-server tool are required to configure zotero-cli.\n' >&2
  exit 1
fi
tool_bin="$(uv tool dir)/zotero-mcp-server/bin"
cli_dir="$(uv tool dir --bin)"
cli="$cli_dir/zotero-cli"
wrapper_marker='# Managed by dotfiles scripts/setup/zotero.sh.'
if [[ ! -x "$tool_bin/zotero-cli" || ! -x "$tool_bin/python" ]]; then
  printf 'Expected a uv-installed Zotero CLI at %s\n' "$tool_bin" >&2
  exit 1
fi
# Check the bundle before changing any installed files. Resolve it again at runtime
# so a uv tool upgrade can move certifi without leaving a stale certificate path.
"$tool_bin/python" -c 'import certifi; from pathlib import Path; assert Path(certifi.where()).is_file()'
if [[ -L "$cli" ]]; then
  if [[ "$(readlink "$cli")" != "$tool_bin/zotero-cli" ]]; then
    printf 'Refusing to replace unrelated symlink: %s\n' "$cli" >&2
    exit 1
  fi
elif [[ -e "$cli" ]]; then
  if [[ ! -f "$cli" ]] || ! grep -Fxq "$wrapper_marker" "$cli"; then
    printf 'Refusing to replace unmanaged launcher: %s\n' "$cli" >&2
    exit 1
  fi
fi

# Preflight workspace paths before changing any installed files.
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

# Replace the public symlink, never the executable inside uv's environment.
# A real launcher works in noninteractive agent shells, unlike an alias.
{
  printf '#!/usr/bin/env bash\n%s\nset -euo pipefail\n' "$wrapper_marker"
  printf 'tool_bin=%q\n' "$tool_bin"
  cat <<'WRAPPER'
if [[ "${SSL_CERT_FILE+x}" != x && "${SSL_CERT_DIR+x}" != x ]]; then
  SSL_CERT_FILE="$("$tool_bin/python" -c 'import certifi; print(certifi.where())')"
  export SSL_CERT_FILE
fi
exec "$tool_bin/zotero-cli" "$@"
WRAPPER
} > "$build_dir/zotero-cli"
mkdir -p "$cli_dir"
# Stage an executable regular file, then rename it over the symlink atomically.
cli_stage="$(mktemp "$cli_dir/.zotero-cli.XXXXXX")"
trap 'rm -rf "$build_dir"; rm -f "$cli_stage"' EXIT
install -m 755 "$build_dir/zotero-cli" "$cli_stage"
mv -f "$cli_stage" "$cli"
printf 'CLI wrapper installed: %s\n' "$cli"
printf '%s\n' "$xpi"
printf '\nProject linked: %s\nInstall the XPI above in Zotero: Tools > Plugins > gear > Install Plugin From File.\nEnable Zotero Settings > Advanced > Allow other applications to communicate with Zotero.\nThen start a NEW Pi/pi-console session in the project and trust its configuration.\n' "$project"

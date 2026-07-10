#!/usr/bin/env bash
set -euo pipefail

# Install nvm + Node without editing shell startup files.
#
# This matches the NVM_DIR/NODE_DEFAULT_PATH convention used by
# bash/bashrc/extras.sh: Node should be usable from ~/.nvm/current/bin without
# loading nvm in every shell.

usage() {
    cat <<'EOF'
Usage: scripts/setup/node.sh [options]

Installs/updates nvm, installs the latest Node available via nvm, sets nvm's
"default" alias to "node", and ensures ~/.nvm/current points at the active
Node version.

This script intentionally does not modify ~/.bashrc, ~/.bash_profile, or other
shell startup files.

Options:
  -h, --help  Show this help

Environment overrides:
  NVM_DIR     Defaults to ~/.nvm
EOF
}

log() {
    printf '\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
    printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2
}

fail() {
    printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    *)
        fail "unknown option: $1"
        ;;
    esac
    shift
done

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

download_to() {
    local url="$1"
    local output="$2"

    if command_exists curl; then
        curl -fsSL "$url" -o "$output"
    elif command_exists wget; then
        wget -q "$url" -O "$output"
    else
        fail "curl or wget is required to download $url"
    fi
}

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export NVM_SYMLINK_CURRENT=true

log "Installing/updating nvm in $NVM_DIR without editing shell profiles"
mkdir -p "$NVM_DIR"

tmpdir="$(mktemp -d)"
installer="$tmpdir/nvm-install.sh"

download_to "https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh" "$installer"
PROFILE=/dev/null bash "$installer" --no-use
rm -rf "$tmpdir"

if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    fail "nvm install did not create $NVM_DIR/nvm.sh"
fi

# shellcheck source=/dev/null
. "$NVM_DIR/nvm.sh" --no-use

log "Installing latest Node via nvm"
nvm install node

log "Setting nvm default alias to node"
nvm alias default node
nvm use default

current_version="$(nvm current)"
current_target="$NVM_DIR/versions/node/$current_version"

if [[ -d "$current_target/bin" ]]; then
    if [[ -L "$NVM_DIR/current" || ! -e "$NVM_DIR/current" ]]; then
        ln -sfn "$current_target" "$NVM_DIR/current"
    else
        warn "$NVM_DIR/current exists and is not a symlink; leaving it unchanged"
    fi
else
    fail "expected Node install at $current_target"
fi

log "Node is ready"
"$NVM_DIR/current/bin/node" --version
"$NVM_DIR/current/bin/npm" --version
printf 'Node default path: %s\n' "$NVM_DIR/current/bin"

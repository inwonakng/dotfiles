#!/usr/bin/env bash
set -euo pipefail

# Install Miniconda without editing shell startup files.
#
# This matches the CONDA_DIR convention used by bash/bashrc/extras.sh,
# including architecture-specific prefixes on shared-home cluster hosts.

FORCE_CONDA=0

usage() {
    cat <<'EOF'
Usage: scripts/setup/conda.sh [options]

Installs Miniconda into the same prefix expected by bash/bashrc/extras.sh.

Default prefixes:
  - mac/non-cluster:       ~/miniconda3
  - blp|dcs|npl clusters:  ~/scratch/miniconda-{x86,ppc,...}

This script intentionally does not modify ~/.bashrc, ~/.bash_profile, or other
shell startup files.

Options:
  --force-reinstall  Remove the target Conda prefix before installing
  -h, --help         Show this help

Environment overrides:
  CONDA_DIR            Overrides auto-detected Conda install prefix
  CONDA_INSTALLER_URL  Overrides auto-detected Miniconda installer URL
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
    --force-reinstall)
        FORCE_CONDA=1
        ;;
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

detect_cluster_arch() {
    local arch
    arch="$(uname -i 2>/dev/null || true)"
    if [[ -z "$arch" ]]; then
        arch="$(uname -m)"
    fi
    printf '%s\n' "$arch"
}

detect_conda_dir() {
    if [[ -n "${CONDA_DIR:-}" ]]; then
        printf '%s\n' "$CONDA_DIR"
        return
    fi

    if [[ "${OSTYPE:-}" == darwin* ]]; then
        printf '%s\n' "$HOME/miniconda3"
        return
    fi

    local hostname_value="${HOSTNAME:-}"
    if [[ -z "$hostname_value" ]]; then
        hostname_value="$(hostname 2>/dev/null || true)"
    fi

    if [[ "$hostname_value" =~ (blp|dcs|npl) ]]; then
        local arch postfix
        arch="$(detect_cluster_arch)"
        case "$arch" in
        x86_64)
            postfix="x86"
            ;;
        ppc64le)
            postfix="ppc"
            ;;
        *)
            warn "unsupported architecture for cluster setup: $arch"
            postfix="$arch"
            ;;
        esac
        printf '%s\n' "$HOME/scratch/miniconda-$postfix"
    else
        printf '%s\n' "$HOME/miniconda3"
    fi
}

detect_miniconda_url() {
    if [[ -n "${CONDA_INSTALLER_URL:-}" ]]; then
        printf '%s\n' "$CONDA_INSTALLER_URL"
        return
    fi

    local os arch platform_arch platform
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$arch" in
    x86_64 | amd64)
        platform_arch="x86_64"
        ;;
    arm64 | aarch64)
        if [[ "$os" == Darwin ]]; then
            platform_arch="arm64"
        else
            platform_arch="aarch64"
        fi
        ;;
    ppc64le)
        platform_arch="ppc64le"
        ;;
    *)
        fail "unsupported Conda installer architecture: $arch"
        ;;
    esac

    case "$os" in
    Darwin)
        platform="MacOSX-${platform_arch}"
        ;;
    Linux)
        platform="Linux-${platform_arch}"
        ;;
    *)
        fail "unsupported Conda installer OS: $os"
        ;;
    esac

    printf 'https://repo.anaconda.com/miniconda/Miniconda3-latest-%s.sh\n' "$platform"
}

conda_dir="$(detect_conda_dir)"
conda_url="$(detect_miniconda_url)"

if [[ -x "$conda_dir/bin/conda" && "$FORCE_CONDA" -eq 0 ]]; then
    log "Conda already exists at $conda_dir; skipping install"
    "$conda_dir/bin/conda" --version || true
    exit 0
fi

if [[ -e "$conda_dir" && "$FORCE_CONDA" -eq 0 ]]; then
    fail "$conda_dir exists but does not contain bin/conda; use --force-reinstall to replace it"
fi

if [[ -e "$conda_dir" && "$FORCE_CONDA" -eq 1 ]]; then
    log "Removing existing Conda prefix $conda_dir"
    rm -rf "$conda_dir"
fi

log "Installing Miniconda to $conda_dir"
log "Installer: $conda_url"
mkdir -p "$(dirname "$conda_dir")"

tmpdir="$(mktemp -d)"
installer="$tmpdir/miniconda.sh"

download_to "$conda_url" "$installer"
bash "$installer" -b -p "$conda_dir"
rm -rf "$tmpdir"

log "Conda is ready"
"$conda_dir/bin/conda" --version
printf 'Conda prefix: %s\n' "$conda_dir"

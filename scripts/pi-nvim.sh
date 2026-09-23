#!/usr/bin/env bash

set -eu

usage() {
    printf 'Usage: %s [--overview | --session PATH]\n' "${0##*/}" >&2
    exit 2
}

unset PI_NVIM_OVERVIEW PI_NVIM_SESSION
export NVIM_APPNAME=pi-nvim

case "$#" in
    0)
        ;;
    1)
        [ "$1" = "--overview" ] || usage
        export PI_NVIM_OVERVIEW=1
        ;;
    2)
        [ "$1" = "--session" ] && [ -n "$2" ] || usage
        export PI_NVIM_SESSION=$2
        ;;
    *)
        usage
        ;;
esac

# Keep the wrapper visible to tmux-resurrect's ~pi-nvim.sh process matcher.
nvim

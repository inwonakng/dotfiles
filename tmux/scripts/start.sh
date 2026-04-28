#!/usr/bin/env bash

set -eu

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-logs"
mkdir -p "$log_dir"

cd "$log_dir"
exec tmux -v "$@"

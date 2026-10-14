#!/usr/bin/env bash

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
pane_id=${1:-$(tmux display-message -p '#{pane_id}')}
client_name=${2:-$(tmux display-message -p -t "$pane_id" '#{client_name}')}
current_session=$(tmux display-message -p -t "$pane_id" '#{session_name}')

if [ "$current_session" = "scratch" ]; then
    if [ -n "$client_name" ]; then
        exec tmux detach-client -t "$client_name"
    else
        exec tmux detach-client
    fi
fi

socket_path=$(tmux display-message -p '#{socket_path}')
exec bash "$script_dir/display-overlay.sh" "$pane_id" "$client_name" 80 85 \
    env -u TMUX tmux -S "$socket_path" new-session -A -s scratch

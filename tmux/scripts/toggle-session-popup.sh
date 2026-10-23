#!/usr/bin/env bash
# Shared routing for persistent session-backed overlays, not command pickers.
set -eu

[ "$#" -ge 3 ] || { printf 'Usage: %s SESSION PANE_ID CLIENT_NAME [COMMAND...]\n' "${0##*/}" >&2; exit 2; }
session=$1
pane_id=${2:-$(tmux display-message -p '#{pane_id}')}
# Do not guess a client from a pane which can have multiple viewers.
client_name=$3
shift 3
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
socket_path=$(tmux display-message -p '#{socket_path}')
current_session=$(tmux display-message -p -t "$pane_id" '#{session_name}')
owned=$(bash "$script_dir/popup-client.sh" --owned "$socket_path" "$client_name")

if [ "$current_session" = "$session" ]; then
    # A normal terminal viewing this session must not be detached by a toggle.
    [ "$owned" != 1 ] || tmux detach-client -t "$client_name"
    exit 0
fi

current_path=$(tmux display-message -p -t "$pane_id" '#{pane_current_path}')
# Serialize creation without using new-session -A, which tries to attach to an
# existing session even when called from this nonterminal launcher.
lock="popup-session-$session"
tmux wait-for -L "$lock"
release_lock() { tmux wait-for -U "$lock"; }
trap release_lock EXIT
if ! tmux has-session -t "=$session" 2>/dev/null; then
    tmux new-session -d -s "$session" -c "$current_path" "$@"
fi
release_lock
trap - EXIT
if [ "$owned" = 1 ]; then
    # Reuse this popup after an intentional switch, rather than nesting one.
    exec tmux switch-client -c "$client_name" -t "=$session"
fi
exec bash "$script_dir/display-overlay.sh" "$pane_id" "$client_name" 80 85 \
    bash "$script_dir/popup-client.sh" "$socket_path" "$session" "$client_name"

#!/usr/bin/env bash

set -eu

if [ "$#" -ne 3 ]; then
    printf 'Usage: %s {break|window|pane} PANE_ID CLIENT_NAME\n' "${0##*/}" >&2
    exit 2
fi

action=$1
pane_id=$2
client_name=$3
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
session_id=$(tmux display-message -p -t "$pane_id" '#{session_id}')
window_id=$(tmux display-message -p -t "$pane_id" '#{window_id}')

case "$action" in
    break)
        prompt='Break pane to session: '
        candidates=$(tmux list-sessions -F '#{session_id} #{session_name}')
        ;;
    window)
        prompt='Move window to session: '
        candidates=$(tmux list-sessions -f "#{!=:#{session_id},$session_id}" \
            -F '#{session_id} #{session_name}')
        ;;
    pane)
        prompt='Move pane to window: '
        candidates=$(tmux list-windows -a -f "#{!=:#{window_id},$window_id}" \
            -F '#{session_id}:#{window_id} #{session_name}:#{window_index} (#{window_name})')
        ;;
    *)
        printf 'Unknown transfer action: %s\n' "$action" >&2
        exit 2
        ;;
esac

selection=$(printf '%s\n' "$candidates" | \
    bash "$script_dir/fzf-picker.sh" "$pane_id" "$client_name" \
        --delimiter=' ' --with-nth=2.. --prompt="$prompt")
target=${selection%% *}
[ -z "$target" ] && exit 0

# The overlay has closed before relocating the original pane or window.
case "$action" in
    break) exec tmux break-pane -d -s "$pane_id" -t "$target:" ;;
    window) exec tmux move-window -s "$window_id" -t "$target:" ;;
    pane) exec tmux move-pane -s "$pane_id" -t "$target" ;;
esac

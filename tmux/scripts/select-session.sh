#!/usr/bin/env bash

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
pane_id=${1:-$(tmux display-message -p '#{pane_id}')}
client_name=${2:-$(tmux display-message -p -t "$pane_id" '#{client_name}')}
current_session_id=$(tmux display-message -p -t "$pane_id" '#{session_id}')

# Keep stable target IDs separate from the labels displayed by fzf.
sessions=$(tmux list-sessions -f "#{!=:#{session_id},$current_session_id}" \
    -F '#{session_id} #{session_name}: #{session_windows} windows (created #{t:session_created})#{?session_grouped, (group #{session_group}),}#{?session_attached, (attached),}')
printf -v preview 'bash %q session {1}' "$script_dir/preview-pane.sh"
selection=$(printf '%s\n[cancel] [cancel]\n' "$sessions" | \
    bash "$script_dir/fzf-picker.sh" "$pane_id" "$client_name" \
        --delimiter=' ' --with-nth=2.. --header='Select target session.' \
        --preview="$preview" --preview-window=top:70%,nowrap)

target=${selection%% *}
[[ "$target" == '[cancel]' || -z "$target" ]] && exit 0
if [ -n "$client_name" ]; then
    exec tmux switch-client -c "$client_name" -t "$target"
else
    exec tmux switch-client -t "$target"
fi

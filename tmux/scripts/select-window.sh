#!/usr/bin/env bash

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
pane_id=${1:-$(tmux display-message -p '#{pane_id}')}
client_name=${2:-$(tmux display-message -p -t "$pane_id" '#{client_name}')}
current_session_id=$(tmux display-message -p -t "$pane_id" '#{session_id}')
current_window_id=$(tmux display-message -p -t "$pane_id" '#{window_id}')

list_windows() {
    tmux list-windows -a -f "#{&&:$1,#{!=:#{window_id},$current_window_id}}" \
        -F '#{session_id}:#{window_id} #{session_name}:#{window_index}: #{window_name} (#{window_width}x#{window_height})#{?window_active, (active),}'
}

# List this session first and exclude the current window, as before.
windows=$(
    list_windows "#{==:#{session_id},$current_session_id}"
    list_windows "#{!=:#{session_id},$current_session_id}"
)
printf -v preview 'bash %q window {1}' "$script_dir/preview-pane.sh"
selection=$(printf '%s\n[cancel] [cancel]\n' "$windows" | \
    bash "$script_dir/fzf-picker.sh" "$pane_id" "$client_name" \
        --delimiter=' ' --with-nth=2.. --header='Select target window.' \
        --preview="$preview" --preview-window=top:70%,nowrap)

target=${selection%% *}
[[ "$target" == '[cancel]' || -z "$target" ]] && exit 0
if [ -n "$client_name" ]; then
    tmux switch-client -c "$client_name" -t "${target%%:*}"
else
    tmux switch-client -t "${target%%:*}"
fi
exec tmux select-window -t "$target"

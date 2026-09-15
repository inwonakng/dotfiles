#!/usr/bin/env bash

plugin_scripts="$HOME/.config/tmux/plugins/tmux-fzf/scripts"
source "$plugin_scripts/.envs"

current_session_id=$(tmux display-message -p '#{session_id}')
current_window=$(tmux display-message -p '#{session_name}:#{window_index}:')

list_windows() {
    local session_filter=$1

    if [[ -n "${TMUX_FZF_WINDOW_FILTER:-}" ]]; then
        session_filter="#{&&:${TMUX_FZF_WINDOW_FILTER},${session_filter}}"
    fi

    if [[ -z "${TMUX_FZF_WINDOW_FORMAT:-}" ]]; then
        tmux list-windows -a -f "$session_filter"
    else
        tmux list-windows -a -f "$session_filter" \
            -F "#S:#{window_index}: $TMUX_FZF_WINDOW_FORMAT"
    fi
}

windows=$(
    list_windows "#{==:#{session_id},$current_session_id}"
    list_windows "#{!=:#{session_id},$current_session_id}"
)

if [[ -z "${TMUX_FZF_SWITCH_CURRENT:-}" ]]; then
    windows=$(while IFS= read -r window; do
        [[ "$window" == "$current_window"* ]] || printf '%s\n' "$window"
    done <<< "$windows")
fi

FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --header='Select target window.'"
target_origin=$(printf '%s\n[cancel]' "$windows" | \
    eval "$TMUX_FZF_BIN $TMUX_FZF_OPTIONS $TMUX_FZF_PREVIEW_OPTIONS")

[[ "$target_origin" == "[cancel]" || -z "$target_origin" ]] && exit
target=${target_origin%%: *}
target_session=${target%%:*}

tmux switch-client -t "$target_session"
tmux select-window -t "$target"

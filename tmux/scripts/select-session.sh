#!/usr/bin/env bash

plugin_scripts="$HOME/.config/tmux/plugins/tmux-fzf/scripts"
source "$plugin_scripts/.envs"

current_session=$(tmux display-message -p '#{session_name}')

if [[ -z "${TMUX_FZF_SESSION_FORMAT:-}" ]]; then
    sessions=$(tmux list-sessions)
else
    sessions=$(tmux list-sessions -F "#S: $TMUX_FZF_SESSION_FORMAT")
fi

if [[ -z "${TMUX_FZF_SWITCH_CURRENT:-}" ]]; then
    sessions=$(while IFS= read -r session; do
        [[ "$session" == "$current_session: "* ]] || printf '%s\n' "$session"
    done <<< "$sessions")
fi

preview_window_option=${TMUX_FZF_PREVIEW_SESSION_OPTIONS##* }
preview_options="--preview='bash $HOME/.config/tmux/scripts/preview-pane.sh session {}' $preview_window_option"
FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --header='Select target session.'"
target_origin=$(printf '%s\n[cancel]' "$sessions" | \
    eval "$TMUX_FZF_BIN $TMUX_FZF_OPTIONS $preview_options")

[[ "$target_origin" == '[cancel]' || -z "$target_origin" ]] && exit
target=${target_origin%%: *}
tmux switch-client -t "$target"

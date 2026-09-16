#!/usr/bin/env bash

set -eu

pane_id=$1
current_path=$(tmux display-message -p -t "$pane_id" '#{pane_current_path}')
current_session=$(tmux display-message -p -t "$pane_id" '#{session_name}')
pi_nvim_command="bash $HOME/dotfiles/scripts/pi-nvim.sh"

if [ "$current_session" = "agents" ]; then
    tmux new-window -c "$current_path" "$pi_nvim_command"
    exit
fi

if tmux has-session -t agents 2>/dev/null; then
    tmux new-window -t agents: -c "$current_path" "$pi_nvim_command"
else
    tmux new-session -d -s agents -c "$current_path" "$pi_nvim_command"
fi

tmux display-popup -w 80% -h 85% -E "tmux new-session -A -s agents"

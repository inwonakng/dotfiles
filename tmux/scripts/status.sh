#!/bin/bash
# script for controlling what is rendered in the status bar
WINDOW_WIDTH=$(tmux display-message -p '#{client_width}')

muted="#[bg=#{@ui_status_bg},fg=#{@ui_muted}]"
host="#[fg=#{@ui_host}]$(hostname -s)"
session="#[fg=#{@ui_session}]#{session_name}"
pane="#[fg=#{@ui_info}]#{pane_id}"

if [ "$WINDOW_WIDTH" -gt 120 ]; then
    status_bar="${host}${muted}·${session}${muted}·${pane}"
else
    status_bar="$pane"
fi

printf '%s| %s%s\n' "$muted" "$status_bar" "$muted"

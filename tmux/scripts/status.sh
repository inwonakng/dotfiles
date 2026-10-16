#!/bin/bash
# script for controlling what is rendered in the status bar
WINDOW_WIDTH=$(tmux display-message -p '#{client_width}')

muted="#[bg=#{@_ctp_status_bg},fg=#{@thm_overlay_2}]"
host="#[fg=#{@thm_peach}]$(hostname -s)"
session="#[fg=#{@thm_lavender}]#{session_name}"
pane="#[fg=#{@thm_teal}]#{pane_id}"

if [ "$WINDOW_WIDTH" -gt 120 ]; then
    status_bar="${host}${muted}·${session}${muted}·${pane}"
else
    status_bar="$pane"
fi

printf '%s| %s%s\n' "$muted" "$status_bar" "$muted"

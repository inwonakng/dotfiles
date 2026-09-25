#!/bin/bash
# script for controlling what is rendered in the status bar
WINDOW_WIDTH=$(tmux display-message -p '#{client_width}')

current_hostname=$(hostname -s)
host=$(printf "#[bg=#{@thm_peach},fg=#{@thm_crust}]#[reverse]#[noreverse]  #[bg=#{@thm_surface_0},fg=#{@thm_fg}] %s " "$current_hostname")
session="#[bg=#{@thm_lavender},fg=#{@thm_crust}]#[reverse]#[noreverse]   #[bg=#{@thm_surface_0},fg=#{@thm_fg}] #{session_name} "
pane="#[bg=#{@thm_teal},fg=#{@thm_crust}]#[reverse]#[noreverse]   #[bg=#{@thm_surface_0},fg=#{@thm_fg}] #{pane_id} "
justpane="#[bg=#{@thm_teal},fg=#{@thm_crust}]#[reverse]#[noreverse]   #[bg=#{@thm_surface_0},fg=#{@thm_fg}] #{pane_id} "

status_bar=""
if [ "$WINDOW_WIDTH" -gt 120 ]; then
    status_bar+="$host"
    status_bar+="$session"
    status_bar+="$pane"
else
    status_bar+="$justpane"
fi

echo "$status_bar"

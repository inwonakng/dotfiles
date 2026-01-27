#!/bin/bash

# Trigger tmux-resurrect save (saves window/pane layouts)
~/.config/tmux/plugins/tmux-resurrect/scripts/save.sh

# Close all Neovim instances gracefully
# This triggers persistence.nvim to save the session state to disk
tmux list-panes -a -F "#{pane_id} #{pane_current_command}" | grep -E "vim|nvim" | while read -r pane_line; do
    pane_id=$(echo "$pane_line" | awk '{print $1}')
    tmux send-keys -t "$pane_id" Escape ":wa" Enter
    tmux send-keys -t "$pane_id" ":qa" Enter
done

# 3. Wait for I/O to finish
sleep 1

# 4. Kill tmux
tmux kill-server

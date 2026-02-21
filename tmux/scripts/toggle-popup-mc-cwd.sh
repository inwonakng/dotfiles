#!/bin/bash

# Get the current session name
current_session=$(tmux display-message -p '#S')

# Check if we're currently in the scratch session (the popup)
if [ "$current_session" = "mc" ]; then
    # We're in the popup, so detach (close it)
    tmux detach-client
else
    # We're not in a popup, so open one
    tmux display-popup -w 80% -h 85% -E "tmux new-session -A -s mc mc"
fi

#!/bin/bash

# only create sessions if none exist
if ! tmux has-session &> /dev/null; then
    # Session for code
    tmux new-session -d -s code -c ~/research
    # Session for misc + notes
    tmux new-session -d -s scratch -n misc
    tmux new-window -t scratch -n notes/work -c ~/Documents/notes/work
    tmux new-window -t scratch -n notes/personal -c ~/Documents/notes/personal
    # Session for writing
    tmux new-session -d -s writing -n writing -c ~/Documents/papers
    # Session for SSHing
    tmux new-session -d -s ssh -n ssh -c ~
fi

# attach to the last used session
tmux attach-session

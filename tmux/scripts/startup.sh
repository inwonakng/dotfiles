#!/bin/bash

# only create sessions if none exist
if ! tmux has-session &> /dev/null; then
    # Session for code
    tmux new-session -d -s code -c ~/research
    # Session for notes
    tmux new-session -d -s notes -n work -c ~/Documents/notes/work
    tmux new-window -t notes -n personal -c ~/Documents/notes/personal
    # dummy session for anything
    tmux new-session -d -s scratch
    # Session for writing
    tmux new-session -d -s writing -n writing -c ~/Documents/papers
    # Session for SSHing
    tmux new-session -d -s ssh -n brains -c ~
    tmux new-window -t ssh -n silkworm -c ~
    tmux new-window -t ssh -n computer3 -c ~
fi

# attach to the last used session
tmux attach-session -t code

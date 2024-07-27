#!/bin/bash

# copied from https://dev.to/acro5piano/edit-tmux-output-with-editor-i1c

file=`mktemp`.sh

tmux capture-pane -pS -32768 > $file
tmux new-window -n:mywindow "$EDITOR '+ normal G $' $file"

#!/bin/bash
# # copied from https://dev.to/acro5piano/edit-tmux-output-with-editor-i1c
#

file=`mktemp`.sh
tmux capture-pane -pS -32768 > $file
tmux new-window -n:mywindow "$EDITOR '+ normal G $' $file"


# # edit-in-vim.sh: Captures the current tmux pane's scrollback and opens it in Vim
# # within the *same pane*.
#
# # Create a temporary file to hold the buffer contents.
# TMPFILE=$(mktemp)
#
# # Capture the entire visible text and scrollback history (-S -) of the current
# # pane and write it to the temporary file.
# tmux capture-pane -pS - > "$TMPFILE"
#
# # Replace the current process in this pane with a new command.
# # -t ${TMUX_PANE} targets the current pane.
# # The command does three things in sequence:
# # 1. Opens Vim with the temporary file.
# # 2. After Vim quits, it removes the temporary file.
# # 3. `exec $SHELL` replaces the script with a new shell, returning you to your prompt.
# tmux respawn-pane -t "${TMUX_PANE:?}" "vim '$TMPFILE'; rm '$TMPFILE'; exec '$SHELL'"

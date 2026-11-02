#!/bin/bash
# Invoked explicitly with bash; no executable bit is required.
set -eu
umask 077
export HS_EDIT_POPUP_DIRECTORY=$3
export HS_EDIT_POPUP_HELPER=$2

if "$1" -n -i NONE --cmd 'set nobackup nowritebackup noundofile' \
    -c 'lua dofile(vim.env.HS_EDIT_POPUP_HELPER)' "$3/buffer.txt"; then
    if [[ ! -f "$3/ready" ]]; then
        result=error
    elif [[ -f "$3/apply" ]]; then
        result=apply
    else
        result=cancel
    fi
else
    result=error
fi
printf '%s\n' "$result" > "$3/result.tmp"
mv "$3/result.tmp" "$3/result"

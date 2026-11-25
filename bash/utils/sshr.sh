#!/usr/bin/env bash

host="${1:-}"
session="${2:-}"
if [[ -z "$host" || "$host" == *[[:space:]]* ]]; then
    echo "Usage: sshr <host> [session]"
    exit 2
fi

remote_command=()
if [[ -n "$session" ]]; then
    # SSH passes the command to the remote login shell.
    remote_command=("tmux new-session -A -s '${session//\'/\'\\\'\'}'")
fi

while true; do
    ssh -tt \
        -o ServerAliveInterval=10 \
        -o ServerAliveCountMax=2 \
        -o ConnectTimeout=7 \
        -- "$host" "${remote_command[@]}"
    rc=$?
    if ((rc != 255)); then
        exit "$rc"
    fi
    echo "Connection lost. Reconnecting in 2s..."
    sleep 2 || exit 130
done

#!/usr/bin/env bash

# Check if we are in an SSH session (Remote).
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    # Popup clients must send directly to the terminal that opened the popup.
    if [ -n "${1-}" ]; then
        script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || exit 1
        socket_path=$(tmux display-message -p '#{socket_path}') || exit 1
        clipboard_client=$(bash "$script_dir/popup-client.sh" --clipboard-client "$socket_path" "$1") || exit 1
        if [ -n "$clipboard_client" ]; then
            exec tmux -S "$socket_path" load-buffer -w -t "$clipboard_client" -
        fi
    fi
    # === REMOTE MODE (OSC 52) ===
    input=$(cat)
    # OSC 52 Header: \033]52;c; (c = clipboard)
    # Payload: Base64 encoded text
    # Footer: \a (Bell)
    # We output to /dev/tty to ensure the escape code reaches the terminal directly
    printf "\033]52;c;%s\a" "$(printf "%s" "$input" | base64 | tr -d '\n')" >/dev/tty

# If not SSH, we are Local.
else
    # === LOCAL MODE ===
    input=$(cat)
    # macOS
    if command -v pbcopy >/dev/null 2>&1; then
        printf "%s" "$input" | pbcopy
    # Wayland
    elif command -v wl-copy >/dev/null 2>&1; then
        printf "%s" "$input" | wl-copy
    # X11
    elif command -v xclip >/dev/null 2>&1; then
        printf "%s" "$input" | xclip -selection clipboard
    fi
fi

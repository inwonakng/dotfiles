#!/usr/bin/env bash

input=$(cat)

# 2. Check if we are in an SSH session (Remote)
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    # === REMOTE MODE (OSC 52) ===
    # Calculate the length of the input
    len=$(printf "%s" "$input" | wc -c)
    # OSC 52 Header: \033]52;c; (c = clipboard)
    # Payload: Base64 encoded text
    # Footer: \a (Bell)
    # We output to /dev/tty to ensure the escape code reaches the terminal directly
    printf "\033]52;c;%s\a" "$(printf "%s" "$input" | base64 | tr -d '\n')" >/dev/tty

# 3. If not SSH, we are Local
else
    # === LOCAL MODE ===
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

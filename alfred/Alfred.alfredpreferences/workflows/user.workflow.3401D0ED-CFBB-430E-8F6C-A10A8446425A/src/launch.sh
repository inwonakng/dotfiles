#!/bin/zsh --no-rcs

stale() {
    (($(date -r "$1" +%s) > $(date -r "$2" +%s)))
}

log() { echo "[DEBUG] $1" >&2 }

readonly directive=$1
readonly exec="./src/WindowNavigator"
# readonly script="${HOME}/${DEV}"
readonly script="./src/WindowNavigator.swift"
readonly header="./src/AccessibilityBridgingHeader.h"
readonly flags=(-suppress-warnings -import-objc-header "$header")

if command -v xcrun &>/dev/null && xcrun --find swiftc &>/dev/null; then
    if [[ -f $exec ]] && ! $(stale $script $exec); then
        $exec $directive
    else
        log "~\nCompiling $script"
        xcrun swiftc -O "${flags[@]}" "$script" -o $exec & # background compilation
        swift "${flags[@]}" "$script" $directive           # immediate execution
    fi
else
    log "~\Running $script"
    swift "${flags[@]}" "$script" $directive # fallback to direct execution (slow)
fi

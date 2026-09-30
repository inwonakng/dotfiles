#!/usr/bin/env bash

set -o pipefail

preview_type=$1
selection=$2

[[ "$selection" == '[cancel]' || -z "$selection" ]] && exit

target=${selection%%: *}
case "$preview_type" in
    session) target="$target:" ;;
    window) ;;
    *) exit 1 ;;
esac

pane_info=$(tmux display-message -p -t "$target" '#{pane_id} #{pane_height}') || exit
read -r pane_id pane_height <<< "$pane_info"

# fzf can skip ANSI state when scrolling or clipping a full-pane capture.
# Separate captures give each row its own attributes; batch them in one call.
capture_commands=()
for ((row = 0; row < pane_height; row++)); do
    ((row > 0)) && capture_commands+=(';')
    capture_commands+=(capture-pane -epN -t "$pane_id" -S "$row" -E "$row")
done

tmux "${capture_commands[@]}" | while IFS= read -r line; do
    printf '\033[0m%s\n' "$line"
done

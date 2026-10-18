#!/usr/bin/env bash

set -eu

if [ "$#" -lt 5 ]; then
    printf 'Usage: %s PANE_ID CLIENT_NAME WIDTH_PERCENT HEIGHT_PERCENT COMMAND [ARGS...]\n' "${0##*/}" >&2
    exit 2
fi

pane_id=$1
client_name=$2
width=$3
height=$4
shift 4
if ! [[ "$width" =~ ^[1-9][0-9]?$|^100$ && "$height" =~ ^[1-9][0-9]?$|^100$ ]]; then
    printf 'Overlay dimensions must be percentages between 1 and 100.\n' >&2
    exit 2
fi

# Inspect the running server, not just the installed client version.
commands=$(tmux list-commands)
modal_supported=0
while read -r name alias flags rest; do
    if [ "$name" = "new-pane" ] && [[ "$flags" == *O* && "$flags" == *K* && "$flags" == *W* ]]; then
        modal_supported=1
        break
    fi
done <<< "$commands"
current_path=$(tmux display-message -p -t "$pane_id" '#{pane_current_path}')

if [ "$modal_supported" -eq 1 ]; then
    # Reuse the popup colors so both overlay implementations look the same.
    # Let the application handle Escape. -W waits and returns its exit status.
    exec tmux new-pane -O -K -W -B none -t "$pane_id" -c "$current_path" \
        -s "$(tmux show-options -gv popup-style)" \
        -x "$width%" -y "$height%" -X "$(((100 - width) / 2))%" -Y "$(((100 - height) / 2))%" \
        bash -eu -c '
            tmux set-option -p -t "$TMUX_PANE" remain-on-exit off
            tmux set-option -p -t "$TMUX_PANE" synchronize-panes off
            exec "$@"
        ' tmux-overlay "$@"
fi

# Older popup implementations parse one command string with /bin/sh, which may
# not support Bash's %q quoting. Single-quote each argument using POSIX syntax.
command=''
for argument in "$@"; do
    command+="'${argument//\'/\'\\\'\'}' "
done
if [ -n "$client_name" ]; then
    exec tmux display-popup -B -c "$client_name" -d "$current_path" -w "$width%" -h "$height%" -E "$command"
else
    exec tmux display-popup -B -t "$pane_id" -d "$current_path" -w "$width%" -h "$height%" -E "$command"
fi

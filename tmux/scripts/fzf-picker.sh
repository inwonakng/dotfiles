#!/usr/bin/env bash

set -eu

if [ "$#" -lt 2 ]; then
    printf 'Usage: %s PANE_ID CLIENT_NAME [FZF_OPTIONS...]\n' "${0##*/}" >&2
    exit 2
fi

pane_id=$1
client_name=$2
shift 2
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# The selectors supply finite lists. Files keep their input and selected output
# separate from the terminal used to display fzf, without background FIFO jobs.
picker_dir=$(mktemp -d "${TMPDIR:-/tmp}/tmux-fzf-picker.XXXXXX")
trap 'rm -rf -- "$picker_dir"' EXIT
cat > "$picker_dir/input"

status=0
bash "$script_dir/display-overlay.sh" "$pane_id" "$client_name" 80 80 \
    env "FZF_DEFAULT_OPTS=${FZF_DEFAULT_OPTS-}" \
        "FZF_DEFAULT_OPTS_FILE=${FZF_DEFAULT_OPTS_FILE-}" \
        "FZF_DEFAULT_COMMAND=${FZF_DEFAULT_COMMAND-}" \
    bash -eu -c '
        picker_dir=$1
        shift
        exec fzf --layout=reverse "$@" --no-multi --no-height --no-tmux --border=none \
            --bind=ctrl-u:half-page-up,ctrl-d:half-page-down \
            --bind=ctrl-f:preview-page-down,ctrl-b:preview-page-up \
            --bind=ctrl-z:ignore < "$picker_dir/input" > "$picker_dir/output"
    ' tmux-fzf-picker "$picker_dir" "$@" || status=$?

case "$status" in
    0) cat "$picker_dir/output" ;;
    1|130) exit 0 ;; # No match or cancellation means no selection.
    *) exit "$status" ;;
esac

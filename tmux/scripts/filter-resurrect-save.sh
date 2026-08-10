#!/usr/bin/env bash

set -euo pipefail

save_file="${1:-}"
if [[ -z "$save_file" || ! -f "$save_file" ]]; then
    exit 0
fi

tmp_file="${save_file}.tmp.$$"
trap 'rm -f "$tmp_file"' EXIT

awk '
BEGIN { FS = OFS = "\t" }

function ignored_nvim_command(command) {
    sub(/^:/, "", command)

    return command ~ /^([^ ]*\/)?nvim .*claude-prompt/ \
        || command ~ /^([^ ]*\/)?nvim \/var\/folders\/.*\/T\/\.?tmp/ \
        || command ~ /^([^ ]*\/)?nvim \/private\/var\/folders\/.*\/T\/\.?tmp/
}

$1 == "pane" && ignored_nvim_command($11) {
    $11 = ":"
}

{ print }
' "$save_file" > "$tmp_file"

mv "$tmp_file" "$save_file"
trap - EXIT

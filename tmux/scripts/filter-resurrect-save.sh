#!/usr/bin/env bash

set -euo pipefail

save_file="${1:-}"
if [[ -z "$save_file" || ! -f "$save_file" ]]; then
    exit 0
fi

tmp_file="${save_file}.tmp.$$"
trap 'rm -f "$tmp_file"' EXIT

awk '
BEGIN {
    FS = OFS = "\t"
    quote = "\047"
    sshr_prefix = ":bash " ENVIRON["HOME"] "/dotfiles/bash/utils/sshr.sh "
}

function shell_quote(value, quoted, pos) {
    quoted = quote
    while ((pos = index(value, quote)) > 0) {
        quoted = quoted substr(value, 1, pos - 1) quote "\\" quote quote
        value = substr(value, pos + 1)
    }
    return quoted value quote
}

function ignored_nvim_command(command) {
    sub(/^:/, "", command)

    return command ~ /^([^ ]*\/)?nvim .*claude-prompt/ \
        || command ~ /^([^ ]*\/)?nvim \/var\/folders\/.*\/T\/\.?tmp/ \
        || command ~ /^([^ ]*\/)?nvim \/private\/var\/folders\/.*\/T\/\.?tmp/
}

$1 == "pane" && ignored_nvim_command($11) {
    $11 = ":"
}

# ps flattens arguments. The host is one word; the remaining text is the session.
$1 == "pane" && index($11, sshr_prefix) == 1 {
    args = substr($11, length(sshr_prefix) + 1)
    separator = index(args, " ")
    host = separator ? substr(args, 1, separator - 1) : args
    $11 = ":sshr " shell_quote(host)
    if (separator) {
        $11 = $11 " " shell_quote(substr(args, separator + 1))
    }
}

{ print }
' "$save_file" > "$tmp_file"

mv "$tmp_file" "$save_file"
trap - EXIT

#!/bin/bash

DIR="$HOME/Documents/projects/search-mail"

# first check the index is good.
uv run --directory "$DIR" python3 "$DIR/index_mail.py"

PREVIEW_CMD="python3 $DIR/preview_mail.py {1}"

uv run --directory "$DIR" python3 "$DIR/query_mail.py" |
    fzf --delimiter "\t" --with-nth 2.. \
        --height=100% \
        --border=none \
        --preview-window 'top:80%:wrap' \
        --preview "$PREVIEW_CMD" \
        --ansi \
        --layout=reverse \
        --header "Search (Standard words AND, \"phrases\", !negation) | Enter to Open" \
        --bind "change:reload:python3 $DIR/query_mail.py {q}" \
        --disabled \
        --bind "enter:execute(open {1})"

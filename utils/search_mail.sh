#!/bin/bash

PYTHON_SCRIPT="$HOME/Documents/projects/search-mail/search_and_index.py"
PYTHON_SCRIPT_DIR="$HOME/Documents/projects/search-mail"
INDEXER="uv run --directory \"$PYTHON_SCRIPT_DIR\" \"$PYTHON_SCRIPT\""

# first check the index is good.
eval "$INDEXER --index"

INITIAL_QUERY=""

if command -v bat &>/dev/null; then
    PREVIEW_CMD="bat --style=numbers --color=always {1}"
else
    PREVIEW_CMD="cat {1}"
fi

eval "$INDEXER --query \"$INITIAL_QUERY\"" |
    fzf --delimiter "\t" --with-nth 2.. \
        --height=100% \
        --border=none \
        --preview-window 'top:85%:wrap' \
        --preview "$PREVIEW_CMD" \
        --ansi \
        --layout=reverse \
        --header "Search (Standard words AND, \"phrases\", !negation) | Enter to Open" \
        --bind "change:reload:python3 $PYTHON_SCRIPT --query {q}" \
        --disabled \
        --bind "enter:execute(open {1})+abort"

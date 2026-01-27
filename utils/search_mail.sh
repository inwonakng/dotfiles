#!/bin/bash

# Check dependencies
if ! command -v fzf &> /dev/null || ! command -v rg &> /dev/null; then
    echo "Error: You need 'fzf' and 'ripgrep' installed."
    echo "Run: brew install fzf ripgrep"
    exit 1
fi

if command -v bat &> /dev/null; then
    PREVIEW_CMD="bat --style=numbers --color=always --highlight-line {2} {1}"
else
    PREVIEW_CMD="cat {1}"
fi

MAIL_DIR="$HOME/Library/Mail"
echo "Searching Apple Mail..."

SELECTED_FILE=$(fzf --ansi --disabled \
    --height=100% \
    --border=none \
    --delimiter : \
    --preview "$PREVIEW_CMD" \
    --preview-window 'top:85%:wrap:+{2}' \
    --bind "start:reload:rg --column --line-number --no-heading --color=always --smart-case --glob '*.emlx' {q} $MAIL_DIR" \
    --bind "change:reload:rg --column --line-number --no-heading --color=always --smart-case --glob '*.emlx' {q} $MAIL_DIR" \
    --query "$1" \
| cut -d: -f1)

# Open Logic
if [ -n "$SELECTED_FILE" ]; then
    echo "Opening in Apple Mail..."
    open "$SELECTED_FILE"
else
    echo "No email selected."
fi

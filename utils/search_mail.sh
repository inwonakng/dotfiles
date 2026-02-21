#!/bin/bash

DIR="$HOME/Documents/projects/search-mail"

# first check the index is good.
uv run --directory "$DIR" python3 "$DIR/index_mail.py"

PREVIEW_CMD="uv run --directory $DIR python3 $DIR/preview_mail.py {1} {q}"

KW_HDR='[KEYWORD] AND words, "phrases", !negation | Enter: open | C-D/U: list  C-F/B: preview | C-E: semantic mode'
SEM_HDR='[SEMANTIC] Enter: open | C-D/U: list  C-F/B: preview | C-E: keyword mode'

TMPMODE=$(mktemp /tmp/mail-search-mode.XXXXXX)
echo "keyword" > "$TMPMODE"
trap "rm -f $TMPMODE" EXIT

uv run --directory "$DIR" python3 "$DIR/query_mail.py" |
    fzf --delimiter "\t" --with-nth 2.. \
        --height=100% \
        --border=none \
        --preview-window 'top:80%:wrap' \
        --preview "$PREVIEW_CMD" \
        --ansi \
        --layout=reverse \
        --header "$KW_HDR" \
        --bind "change:transform:[ \$(cat $TMPMODE) = semantic ] && echo 'reload:uv run --directory $DIR python3 $DIR/query_mail.py --semantic {q}' || echo 'reload:uv run --directory $DIR python3 $DIR/query_mail.py {q}'" \
        --disabled \
        --bind "ctrl-d:half-page-down,ctrl-u:half-page-up" \
        --bind "ctrl-f:preview-page-down,ctrl-b:preview-page-up" \
        --bind "esc:ignore" \
        --bind "enter:execute(open {1})" \
        --bind "ctrl-e:transform:if [ \$(cat $TMPMODE) = semantic ]; then echo keyword > $TMPMODE; echo 'reload:uv run --directory $DIR python3 $DIR/query_mail.py {q}'; echo 'change-header($KW_HDR)'; else echo semantic > $TMPMODE; echo 'reload:uv run --directory $DIR python3 $DIR/query_mail.py --semantic {q}'; echo 'change-header($SEM_HDR)'; fi"

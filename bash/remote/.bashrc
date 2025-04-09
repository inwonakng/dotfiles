# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions

ARCH=$(uname -i)

# you can store architecture specific binaries in ~/.local/bin/$ARCH
# and add to path so you can use system-wide
case $ARCH in
x86_64)
    POSTFIX="x86"
    # export LD_LIBRARY_PATH="/usr/local/cuda-11.2/targets/x86_64-linux/"
    ;;
ppc64le)
    POSTFIX="ppc"
    ;;
esac

CONDA_PARENT_DIR="$HOME"
case $HOSTNAME in
*blp*)
    export http_proxy=http://proxy:8888
    export https_proxy=$http_proxy
    CONDA_PARENT_DIR="$HOME/scratch"
    ;;
*dcs*)
    export http_proxy=http://proxy:8888
    export https_proxy=$http_proxy
    CONDA_PARENT_DIR="$HOME/scratch"
    ;;
*npl*)
    export http_proxy=http://proxy:8888
    export https_proxy=$http_proxy
    CONDA_PARENT_DIR="$HOME/scratch"
    ;;
esac

CONDA_DIR="$CONDA_PARENT_DIR/miniconda-$POSTFIX"

function load_conda() {
    # >>> conda initialize >>>
    # !! Contents within this block are managed by 'conda init' !!
    __conda_setup="$("$CONDA_DIR/bin/conda" 'shell.bash' 'hook' 2>/dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "$CONDA_DIR/etc/profile.d/conda.sh" ]; then
            . "$CONDA_DIR/etc/profile.d/conda.sh"
        fi
    fi
    unset __conda_setup
    # <<< conda initialize <<<
    export PATH="$CONDA_DIR/bin:$PATH"
}

# leaving this here in case I ever need to load something else (like nvm)
function load() {
    case $1 in
    conda)
        load_conda
        echo "conda is loaded"
        ;;
    *)
        echo "Usage: load {conda|nvm}"
        return 1
        ;;
    esac
}

# prepend local binaries to path.
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin/$POSTFIX:$PATH"

# if fzf is installed, set it up here
if [[ -d "$HOME/.fzf-$POSTFIX" ]]; then
    if [[ ! "$PATH" == *$HOME/.fzf-$POSTFIX/bin* ]]; then
        PATH="${PATH:+${PATH}:}$HOME/.fzf-$POSTFIX/bin"
    fi
    eval "$(fzf --bash)"
fi

# set input to vi mode
set -o vi
export EDITOR="vim"

edit_command_line() {
    # Create a temporary file
    local TMP_FILE=$(mktemp)

    # Save current command line to the temporary file
    echo "$READLINE_LINE" >"$TMP_FILE"

    # Open vim to edit the command line
    $EDITOR "$TMP_FILE"

    # Set the command line to the modified contents of the temporary file
    READLINE_LINE=$(cat "$TMP_FILE")
    READLINE_POINT=${#READLINE_LINE} # Move the cursor to the end of the line

    # Clean up
    rm "$TMP_FILE"
}

# Bind Ctrl+O to the custom function
bind -x '"\C-o": edit_command_line'
bind -m vi-command '"v": abort'

# alias for pretty ls
alias ls="ls --color"

export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height=40% --preview-window=right:50%:wrap'
export FZF_CTRL_T_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'bat -n --color=always {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"
export FZF_CTRL_R_OPTS="
  --preview 'echo {}' --preview-window up:3:hidden:wrap
  --bind 'ctrl-/:toggle-preview'
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --color header:italic
  --header 'Press CTRL-Y to copy command into clipboard'"
export FZF_ALT_C_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'tree -C {}'"

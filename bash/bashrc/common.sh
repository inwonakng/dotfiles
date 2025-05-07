# add stuff to path if exists
# if fzf is installed, set it up here
[ -f $FZF_SCRIPT_FILE ] && source $FZF_SCRIPT_FILE
if [[ -d $FZF_DIR ]]; then
    if [[ ! "$PATH" == *$FZF_DIR/bin* ]]; then
        PATH="${PATH:+${PATH}:}$FZF_DIR/bin"
    fi
    eval "$(fzf --bash)"
fi

[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
[ -f "$HOME/.config/ripgrep/config" ] && export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"

# completions
[ -f "$HOME/.bash_utils/completions/git.bash" ] && source "$HOME/.bash_utils/completions/git.bash"
[ -f "$HOME/.bash_utils/completions/slurm.bash" ] && source "$HOME/.bash_utils/completions/slurm.bash"
[ -f "$HOME/.bash_utils/completions/python-modules.bash" ] && source "$HOME/.bash_utils/completions/python-modules.bash"
[ -f "$HOME/.bash_utils/completions/aichat.bash" ] && source "$HOME/.bash_utils/completions/aichat.bash"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# add local bin

[ -d "$LOCAL_BIN_DIR" ] && export PATH="$LOCAL_BIN_DIR:$PATH"

# selective loading of stuff
# CONDA_DIR and NVM_DIR should have been set in the sourcing script

function load_nvm() {
    source "$NVM_DIR/nvm.sh"
}

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


function load() {
    case $1 in
    nvm)
        load_nvm
        echo "NVM is loaded"
        ;;
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

# yazi stuff
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

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
# FZF config

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

# if installed, overwrite cd
if command -v "zoxide" >/dev/null 2>&1; then
    eval "$(zoxide init bash --cmd cd)"
    alias z="cd"
    alias zi="cdi"
fi

alias g="lazygit"
alias ls="ls --color"

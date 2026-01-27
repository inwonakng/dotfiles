# add local bin
[ -d "$LOCAL_BIN_DIR" ] && export PATH="$LOCAL_BIN_DIR:$PATH"

######################
## INTERACTIVE ONLY ##
######################
if [[ $- != *i* ]]; then
    return
fi

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
[ -f "$HOME/.bash_utils/completions/aichat.bash" ] && source "$HOME/.bash_utils/completions/aichat.bash"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion" # This loads nvm bash_completion

# selective loading of stuff
# CONDA_DIR and NVM_DIR should have been set in the sourcing script

function load_nvm() {
    source "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
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

function load_pixi() {
    if [[ -d "$HOME/.pixi" ]]; then
        eval "$(pixi completion --shell bash)"
    fi
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
    pixi)
        load_pixi
        echo "pixi is loaded"
        ;;
    *)
        echo "Usage: load {conda|nvm}"
        return 1
        ;;
    esac
}

# override cd to use pushd, but keep standard behavior for 'cd' and 'cd -'
cd() {
    if [ "$#" -eq 0 ]; then
        # No arguments: standard 'cd' behavior (go home)
        builtin cd "$HOME"
    elif [ "$1" = "-" ]; then
        # 'cd -': standard 'cd' behavior (go previous)
        builtin cd "$OLDPWD"
    else
        # Otherwise: pushd to the directory, suppress stdout
        builtin pushd "$1" > /dev/null
    fi
}

edit_command_line() {
    # Create a temporary file
    local TMP_FILE=$(mktemp)
    # Save current command line to the temporary file
    echo "$READLINE_LINE" >"$TMP_FILE"
    # Open vim to edit the command line
    IS_TEMP_SESSION=1 $EDITOR $TMP_FILE
    # Set the command line to the modified contents of the temporary file
    READLINE_LINE=$(cat "$TMP_FILE")
    READLINE_POINT=${#READLINE_LINE} # Move the cursor to the end of the line
    # Clean up
    rm "$TMP_FILE"
}

# Bind Ctrl+e to the custom function
if [[ "$(set -o | grep 'emacs\|\bvi\b' | cut -f2 | tr '\n' ':')" != 'off:off:' ]]; then
    # standard output is a tty
    # do interactive initialization
    bind -x '"\C-e": edit_command_line'
    bind -m vi-command '"v": abort'
fi

scratch() {
    IS_TEMP_SESSION=1 $EDITOR $SCRATCH_NOTE_FILE
}
if [[ "$(set -o | grep 'emacs\|\bvi\b' | cut -f2 | tr '\n' ':')" != 'off:off:' ]]; then
    # Binds C-g to execute the 'scratchpad' command and then redraw the prompt.
    bind '"\C-g": "scratch\n"'
fi

# FZF config
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height=40% --preview-window=right:50%:wrap --bind ctrl-f:page-down,ctrl-b:page-up'

# i got this from here:
# https://thevaluable.dev/practical-guide-fzf-example/
export FZF_CTRL_T_OPTS="--multi --height=80% --border=sharp \
--preview='tree -C {}' --preview-window='45%,border-sharp' \
--prompt='Dirs > ' \
--bind='del:execute(rm -ri {+})' \
--bind='ctrl-v:toggle-preview' \
--bind='ctrl-d:change-prompt(Dirs > )' \
--bind='ctrl-d:+reload(fd --type d)' \
--bind='ctrl-d:+change-preview(tree -C {})' \
--bind='ctrl-d:+refresh-preview' \
--bind='ctrl-f:change-prompt(Files > )' \
--bind='ctrl-f:+reload(fd --type f)' \
--bind='ctrl-f:+change-preview(bat {})' \
--bind='ctrl-f:+refresh-preview' \
--bind='ctrl-a:select-all' \
--bind='ctrl-x:deselect-all' \
--header '
    CTRL-D to display directories | CTRL-F to display files
    CTRL-A to select all | CTRL-x to deselect all
    ENTER to edit | DEL to delete
    CTRL-V to toggle preview
'"

export FZF_CTRL_R_OPTS="
  --preview 'echo {}' --preview-window up:3:hidden:wrap
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --color header:italic
  --header 'Press CTRL-Y to copy command into clipboard'"

# rebind alt-c into ctrl+p
export FZF_ALT_C_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'tree -C {}'"

# FZF_ALT_C_COMMAND="CTRL-K"
fzf_cd_pushd() {
    local cmd
    cmd="$(__fzf_cd__)" || return
    cmd=${cmd/builtin cd/pushd}
    eval "$cmd" >/dev/null || return
    # show where we landed since the prompt may not redraw immediately
    printf 'pushd %s\n' "$PWD"
    READLINE_LINE=""
    READLINE_POINT=0
}
bind -x '"\C-k": "fzf_cd_pushd"'

# if installed activate zoxide (for shell pwd history)
if command -v "zoxide" >/dev/null 2>&1; then
    eval "$(zoxide init bash --cmd cd)"
    alias z="cd"
    alias zi="cdi"
fi

# vi mode/editors setup
set -o vi

if command -v "nvim" >/dev/null 2>&1; then
    # alias nvim="nvim --cmd 'set rtp+=~/.config/nvim'"
    # if we have neovim installed, assume we have oil.nvim
    export EDITOR="nvim"
    export VISUAL="nvim"
else
    export EDITOR="vim"
    export VISUAL="vim"
fi

alias mail-search="bash $HOME/dotfiles/utils/search_mail.sh"
alias g="lazygit"
alias ls="ls --color"
alias oil-ssh="bash $HOME/.bash_utils/oil-ssh.sh"
# remove global conda from path... i don't use this
export PATH=$(echo "$PATH" | sed -e 's/:\/software\/anaconda3.24\/bin//g')

# if pixi is installed, just add to path. this doesn't auto load the full thing though.
if [[ -d "$HOME/.pixi" ]]; then
    export PATH="$HOME/.pixi/bin:$PATH"
fi

# load prompt
if [ -f ~/.bash_utils/prompt.sh ]; then
    source ~/.bash_utils/prompt.sh
fi

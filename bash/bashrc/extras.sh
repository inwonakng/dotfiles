# vi mode/editors setup.
set -o vi

################################
## OS-Specific Configurations ##
################################
if [[ "$OSTYPE" == "darwin"* ]]; then
    # NOTE: for now, we assume mac is always a local machine.
    export HOMEBREW_NO_AUTO_UPDATE=true
    export HOMEBREW_PATH="/opt/homebrew/bin"
    if [ -d /opt/homebrew/bin ]; then
        PATH="$HOMEBREW_PATH:$PATH"
    fi
    # add local bin
    [ -d "$LOCAL_BIN_DIR" ] && export PATH="$LOCAL_BIN_DIR:$PATH"
    CONDA_DIR="$HOME/miniconda3"
    NVM_DIR="$HOME/.nvm"
    FZF_DIR=""
    LOCAL_BIN_DIR="$HOME/.local/bin"
    FZF_SCRIPT_FILE="$HOME/.fzf.bash"
    SCRATCH_NOTE_FILE="$HOME/.cache/scratch.md"
    export PYTHON_DEFAULT_PATH="$CONDA_DIR/envs/scripts/bin"
    export NODE_DEFAULT_PATH="$NVM_DIR/versions/node/v22.16.0/bin"
    export PATH="$NODE_DEFAULT_PATH:$PATH"
else
    # NOTE: to self. the reason we do it like this is b/c there are cases where a the same directory erves as an entry point to multiple compute nodes with different architectures. In that case, we must keep a separation of binaries for each architecture.
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
    # prepend local binaries to path.
    LOCAL_BIN_DIR="$HOME/.local/bin/$POSTFIX"

    CONDA_PARENT_DIR="$HOME"
    # this is specific for RPI clusters. if the hostname contains one of these substrings, we are on a cluster and need to set up the proxy and conda parent dir accordingly.
    if [[ "$HOSTNAME" =~ "blp|dcs|npl" ]]; then
        export http_proxy=http://proxy:8888
        export https_proxy=$http_proxy
        CONDA_PARENT_DIR="$HOME/scratch"
    fi
    CONDA_DIR="$CONDA_PARENT_DIR/miniconda-$POSTFIX"
    NVM_DIR="$HOME/.nvm"
    FZF_DIR="$HOME/.fzf-$POSTFIX"
    FZF_SCRIPT_FILE="$HOME/.fzf-$PREFIX.bash"
    SCRATCH_NOTE_FILE="$HOME/scratch.md"
    export PYTHON_DEFAULT_PATH="$CONDA_DIR/envs/scripts/bin"
    export NODE_DEFAULT_PATH="$NVM_DIR/versions/node/v22.15.0/bin"
    export PATH="$NODE_DEFAULT_PATH:$PATH"
fi

# at this point, we have finished linking the necessary binaries/paths we need

###################################
## Exit early if not interactive ##
###################################
if [[ $- != *i* ]]; then
    return
fi

################
## PATH Setup ##
################

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

#######################
## Completions Setup ##
#######################

[ -f "/opt/homebrew/etc/profile.d/bash_completion.sh" ] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"
[ -f "$HOME/.bash_utils/completions/git.bash" ] && source "$HOME/.bash_utils/completions/git.bash"
[ -f "$HOME/.bash_utils/completions/slurm.bash" ] && source "$HOME/.bash_utils/completions/slurm.bash"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion" # This loads nvm bash_completion

# selective loading of stuff
# CONDA_DIR and NVM_DIR should have been set in the sourcing script

######################
## Custon Functions ##
######################

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
        builtin pushd "$1" >/dev/null
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
    bind -m vi-insert -x '"\C-e": edit_command_line'
    bind -m vi-command '"v": abort'
fi

scratch() {
    IS_TEMP_SESSION=1 $EDITOR $SCRATCH_NOTE_FILE
}
if [[ "$(set -o | grep 'emacs\|\bvi\b' | cut -f2 | tr '\n' ':')" != 'off:off:' ]]; then
    # Binds C-g to execute the 'scratchpad' command and then redraw the prompt.
    bind '"\C-g": "scratch\n"'
fi

############################
## FZF Full Configuration ##
############################

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
bind -m vi-insert -x '"\C-k": "fzf_cd_pushd"'

###################################
## Alaising/Overriding Variables ##
###################################

# if installed activate zoxide (for shell pwd history)
if command -v "zoxide" >/dev/null 2>&1; then
    eval "$(zoxide init bash --cmd cd)"
    alias z="cd"
    alias zi="cdi"
fi

if command -v "nvim" >/dev/null 2>&1; then
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
alias tmux-kill="bash ~/dotfiles/tmux/scripts/clean-exit.sh"
# remove global conda from path... i don't use this
export PATH=$(echo "$PATH" | sed -e 's/:\/software\/anaconda3.24\/bin//g')

# if pixi is installed, just add to path. this doesn't auto load the full thing though.
if [[ -d "$HOME/.pixi" ]]; then
    export PATH="$HOME/.pixi/bin:$PATH"
fi

###################
## CUSTOM PROMPT ##
###################

# Function to get current conda environment name
function parse_conda_env {
    if [[ -n $CONDA_DEFAULT_ENV ]]; then
        echo "($CONDA_DEFAULT_ENV)"
    fi
}

function parse_cwd {
    local dir=$PWD
    local max_length=40
    local home_dir=$HOME

    # Replace home directory with ~
    if [[ $dir == $home_dir* ]]; then
        dir="~${dir#$home_dir}"
    fi

    if [ ${#dir} -le $max_length ]; then
        echo "$dir"
    else
        # Split the path into an array of directories
        IFS='/' read -r -a parts <<<"$dir"
        local length=${#parts[@]}

        # Keep the first part, last three parts, and truncate the middle
        local first_part=${parts[0]}
        local truncated_parts=("${parts[@]: -3}")

        # Join the truncated parts with slashes
        local joined_parts=$(
            IFS='/'
            echo "${truncated_parts[*]}"
        )

        echo "…/$joined_parts"
    fi
}

function newline_if_needed {
    # Save the cursor position
    echo -ne '\e7'
    # Move the cursor to the beginning of the current line
    echo -ne '\e[1G'
    # Check if the cursor is at the beginning of the line (column 1)
    echo -ne '\e[6n'
    read -sdR cursor_position
    cursor_position=${cursor_position#*[}
    cursor_position=${cursor_position%;*}
    if [ "$cursor_position" -gt 1 ]; then
        # Restore the cursor position and print a newline if not at the top
        echo -ne '\e8\n'
    else
        # Restore the cursor position
        echo -ne '\e8'
    fi
}

# detect session type
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    # SSH session
    export SESSION_TYPE=remote/ssh
else
    case $(ps -o comm= -p "$PPID") in
    sshd | */sshd) export SESSION_TYPE=remote/ssh ;;
    esac
    # Local session
    export SESSION_TYPE=local
fi

# color reference: https://misc.flogisoft.com/bash/tip_colors_and_formatting

WHITE="\[\e[0m\]"
GREEN="\[\e[32m\]"
BROWN="\[\e[33m\]"
BLUE="\[\e[34m\]"
PURPLE="\[\e[35m\]"
CYAN="\[\e[36m\]"
PINKORANGE="\[\e[38;5;212m\]"
DARKPINKORANGE="\[\e[38;5;167m\]"

HOST_COLOR=$CYAN
if [ "$SESSION_TYPE" == "remote/ssh" ]; then
    HOST_COLOR=$DARKPINKORANGE
fi

# Custom PS1
PS1="$GREEN"' \D{%Y-%m-%d} '
PS1+="$BLUE"'  $(parse_cwd) '
PS1+="$BROWN"'$(parse_conda_env)\n'
PS1+="$WHITE"'\u'
PS1+="$PINKORANGE"'@'"$HOST_COLOR"'\h'
PS1+="$CYAN"' → '"$WHITE"

# only add this hook if zoxide is installed.
if command -v "zoxide" >/dev/null 2>&1; then
    PS1+="\$(__zoxide_hook)"
fi

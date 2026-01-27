# .bashrc
# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# OS Specific stuff
if [[ "$OSTYPE" == "darwin"* ]]; then
    export HOMEBREW_NO_AUTO_UPDATE=true
    export HOMEBREW_PATH="/opt/homebrew/bin"
    if [ -d /opt/homebrew/bin ]; then
        PATH="$HOMEBREW_PATH:$PATH"
    fi
fi

# mac specific stuff
[ -f "/opt/homebrew/etc/profile.d/bash_completion.sh" ] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"
alias tmux-setup="bash ~/dotfiles/tmux/scripts/startup-local.sh"
alias tmux-kill="bash ~/dotfiles/tmux/scripts/clean-exit.sh"

# variables needed by common script
CONDA_DIR="$HOME/miniconda3"
NVM_DIR="$HOME/.nvm"
FZF_DIR=""
LOCAL_BIN_DIR="$HOME/.local/bin"
FZF_SCRIPT_FILE="$HOME/.fzf.bash" 
SCRATCH_NOTE_FILE="$HOME/.cache/scratch.md"

export NODE_DEFAULT_PATH="$NVM_DIR/versions/node/v22.16.0/bin"
export PYTHON_DEFAULT_PATH="$CONDA_DIR/envs/scripts/bin"
# update path with default node so we use this instead
export PATH="$NODE_DEFAULT_PATH:$PATH"

# we assume this is where the dotfiles repo is located
source "$HOME/dotfiles/bash/bashrc/extras.sh"

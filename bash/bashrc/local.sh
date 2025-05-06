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
    # add wezterm to path if it exists
    if [ -d /Applications/WezTerm.app ]; then
        PATH="$PATH:/Applications/WezTerm.app/Contents/MacOS"
    fi
fi

CONDA_DIR="$HOME/miniconda3"
FZF_DIR=""
LOCAL_BIN_DIR="$HOME/.local/bin"
FZF_SCRIPT_FILE="$HOME/.fzf.bash" 

export NODE_DEFAULT_PATH="$HOME/.nvm/versions/node/v22.14.0/bin"
export PYTHON_DEFAULT_PATH="$HOME/miniconda3/envs/scripts/bin"
# update path with default node so we use this instead
export PATH="$NODE_DEFAULT_PATH:$PATH"

set -o vi
export EDITOR='nvim'

[ -f "/opt/homebrew/etc/profile.d/bash_completion.sh" ] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"
export AICHAT_CONFIG_DIR="$HOME/.config/aichat"

# mac specific
export PATH=$PATH:"$HOME/.term-utils"
alias sioyek="/Applications/sioyek.app/Contents/MacOS/sioyek"

source "$HOME/.bashrc-extras"

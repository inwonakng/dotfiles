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

# prepend local binaries to path.
LOCAL_BIN_DIR="$HOME/.local/bin/$POSTFIX"

# [ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin/$POSTFIX:$PATH"

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
FZF_DIR="$HOME/.fzf-$POSTFIX" 
FZF_SCRIPT_FILE="$HOME/.fzf-$PREFIX.bash" 

# set input to vi mode
set -o vi
export EDITOR="vim"

source "$HOME/.bashrc-extras"

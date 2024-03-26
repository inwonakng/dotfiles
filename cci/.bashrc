# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions

ARCH=$(uname -i)

case $ARCH in
x86_64)
	CONDA_DIR="miniconda-x86"
	;;
ppc64le)
	echo "is ppc"
	CONDA_DIR="miniconda-ppc"
	;;
esac

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$("$HOME/scratch/$CONDA_DIR/bin/conda" 'shell.bash' 'hook' 2>/dev/null)"
if [ $? -eq 0 ]; then
	eval "$__conda_setup"
else
	if [ -f "$HOME/scratch/$CONDA_DIR/etc/profile.d/conda.sh" ]; then
		. "$HOME/scratch/$CONDA_DIR/etc/profile.d/conda.sh"
	else
		export PATH="$HOME/scratch/$CONDA_DIR/bin:$PATH"
	fi
fi
unset __conda_setup
# <<< conda initialize <<<


# set input to vi mode
set -o vi

# alias for pretty ls
alias ls="ls --color"

# auxiliary stuff that only works in x86
if [ $ARCH != "x86_64" ]; then
  # set PATH so it includes user's private bin if it exists
  if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
  fi

  export FZF_DEFAULT_OPTS='--height=40% --preview="cat {}" --preview-window=right:50%:wrap'
  [ -f ~/.fzf.bash ] && source ~/.fzf.bash
fi

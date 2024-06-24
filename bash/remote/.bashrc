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

CONDA_DIR="miniconda-$POSTFIX"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$("$HOME/$CONDA_DIR/bin/conda" 'shell.bash' 'hook' 2>/dev/null)"
if [ $? -eq 0 ]; then
	eval "$__conda_setup"
else
	if [ -f "$HOME/$CONDA_DIR/etc/profile.d/conda.sh" ]; then
		. "$HOME/$CONDA_DIR/etc/profile.d/conda.sh"
	else
		export PATH="$HOME/$CONDA_DIR/bin:$PATH"
	fi
fi
unset __conda_setup
# <<< conda initialize <<<

[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin/$POSTFIX:$PATH"
[ -f "$HOME/.fzf-$POSTFIX.bash" ] && source "$HOME/.fzf-$POSTFIX.bash"

# set input to vi mode
set -o vi
export EDITOR="vim"

edit_command_line() {
	# Create a temporary file
	local TMP_FILE=$(mktemp)

	# Save current command line to the temporary file
	echo "$READLINE_LINE" >"$TMP_FILE"

	# Open vim to edit the command line
	vim "$TMP_FILE"

	# Set the command line to the modified contents of the temporary file
	READLINE_LINE=$(cat "$TMP_FILE")
	READLINE_POINT=${#READLINE_LINE} # Move the cursor to the end of the line

	# Clean up
	rm "$TMP_FILE"
}

# Bind Ctrl+E to the custom function
bind -x '"\C-e": edit_command_line'

# alias for pretty ls
alias ls="ls --color"

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

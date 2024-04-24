# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$("$HOME/miniconda3/bin/conda" 'shell.bash' 'hook' 2>/dev/null)"
if [ $? -eq 0 ]; then
	eval "$__conda_setup"
else
	if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
		. "$HOME/miniconda3/etc/profile.d/conda.sh"
	else
		export PATH="$HOME/miniconda3/bin:$PATH"
	fi
fi
unset __conda_setup
# <<< conda initialize <<<

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ]; then
	export PATH="$HOME/.local/bin:$PATH"
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

export FZF_DEFAULT_OPTS='--height=40% --preview="cat {}" --preview-window=right:50%:wrap'
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

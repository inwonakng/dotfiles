# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# OS Specific stuff
if [[ "$OSTYPE" == "darwin"* ]]; then
	export HOMEBREW_NO_AUTO_UPDATE=true
	if [ -d /opt/homebrew/bin ]; then
		PATH="/opt/homebrew/bin:$PATH"
	fi
	# add wezterm to path if it exists
	if [ -d /Applications/WezTerm.app ]; then
		PATH="$PATH:/Applications/WezTerm.app/Contents/MacOS"
	fi
fi

export NVM_DIR="$HOME/.nvm"
if [[ "$OSTYPE" == "darwin"* ]]; then
	nvim_prefix=$(brew --prefix nvm)
else
	nvim_prefix="${HOME}/.nvm"
fi

source "${nvim_prefix}/nvm.sh"
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/inwon/miniconda3/bin/conda' 'shell.zsh' 'hook' 2>/dev/null)"
if [ $? -eq 0 ]; then
	eval "$__conda_setup"
else
	if [ -f "/Users/inwon/miniconda3/etc/profile.d/conda.sh" ]; then
		. "/Users/inwon/miniconda3/etc/profile.d/conda.sh"
	else
		export PATH="/Users/inwon/miniconda3/bin:$PATH"
	fi
fi
unset __conda_setup

# [ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin/$POSTFIX:$PATH"
[ -f "$HOME/.fzf.bash" ] && source "$HOME/.fzf.bash"

# set input to vi mode
set -o vi
# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
# 	export EDITOR='vim'
# else
export EDITOR='nvim'
# fi

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

# Bind Ctrl+E to the custom function
bind -x '"\C-e": edit_command_line'
bind -m vi-command '"v": abort'

# Custom aliases
alias code="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"
alias latex="latexmk -bibtex -pdf -pvc -output-directory=.cache -quiet -silent"

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

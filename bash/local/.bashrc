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

# use this as the default node version. When nvm is activated, it should prepend on this.
export NODE_DEFAULT_PATH="$HOME/.nvm/versions/node/v18.20.5/bin"
export PATH="$NODE_DEFAULT_PATH:$PATH"

# use this as the default node version. When nvm is activated, it should prepend on this.
export PYTHON_DEFAULT_PATH="$HOME/miniconda3/envs/scripts/bin"
# export PATH="$PYTHON_DEFAULT_PATH:$PATH"

function load_nvm() {
  source "$HOME/.nvm/nvm.sh"
}

function load_conda() {
  # >>> conda initialize >>>
  # !! Contents within this block are managed by 'conda init' !!
  __conda_setup="$("$HOME/miniconda3/bin/conda" 'shell.zsh' 'hook' 2>/dev/null)"
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

[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
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

export PATH=$PATH:"$HOME/.term-utils"
alias sioyek="/Applications/sioyek.app/Contents/MacOS/sioyek"

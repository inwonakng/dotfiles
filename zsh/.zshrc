# # start profiling
# if [ -n "${ZSH_DEBUGRC+1}" ]; then
#     zmodload zsh/zprof
# fi
#
# # Start configuration added by Zim install {{{
# #
# # User configuration sourced by interactive shells
# #
#
# # -----------------
# # Zsh configuration
# # -----------------
#
# #
# # History
# #
#
# # Remove older command from the history if a duplicate is to be added.
# setopt HIST_IGNORE_ALL_DUPS
#
# #
# # Input/output
# #
#
# # Set editor default keymap to emacs (`-e`) or vi (`-v`)
# bindkey -v
#
# # Prompt for spelling correction of commands.
# #setopt CORRECT
#
# # Customize spelling correction prompt.
# #SPROMPT='zsh: correct %F{red}%R%f to %F{green}%r%f [nyae]? '
#
# # Remove path separator from WORDCHARS.
# WORDCHARS=${WORDCHARS//[\/]}
#
# # -----------------
# # Zim configuration
# # -----------------
#
# # Use degit instead of git as the default tool to install and update modules.
# #zstyle ':zim:zmodule' use 'degit'
#
# # --------------------
# # Module configuration
# # --------------------
#
# #
# # git
# #
#
# # Set a custom prefix for the generated aliases. The default prefix is 'G'.
# #zstyle ':zim:git' aliases-prefix 'g'
#
# #
# # input
# #
#
# # Append `../` to your input for each `.` you type after an initial `..`
# #zstyle ':zim:input' double-dot-expand yes
#
# #
# # termtitle
# #
#
# # Set a custom terminal title format using prompt expansion escape sequences.
# # See http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html#Simple-Prompt-Escapes
# # If none is provided, the default '%n@%m: %~' is used.
# #zstyle ':zim:termtitle' format '%1~'
#
# #
# # zsh-autosuggestions
# #
#
# # Disable automatic widget re-binding on each precmd. This can be set when
# # zsh-users/zsh-autosuggestions is the last module in your ~/.zimrc.
# ZSH_AUTOSUGGEST_MANUAL_REBIND=1
#
# # Customize the style that the suggestions are shown with.
# # See https://github.com/zsh-users/zsh-autosuggestions/blob/master/README.md#suggestion-highlight-style
# #ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'
#
# #
# # zsh-syntax-highlighting
# #
#
# # Set what highlighters will be used.
# # See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters.md
# ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
#
# # Customize the main highlighter styles.
# # See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters/main.md#how-to-tweak-it
# #typeset -A ZSH_HIGHLIGHT_STYLES
# #ZSH_HIGHLIGHT_STYLES[comment]='fg=242'
#
# # ------------------
# # Initialize modules
# # ------------------
#
# ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim
# # Download zimfw plugin manager if missing.
# if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
#   if (( ${+commands[curl]} )); then
#     curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
#         https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
#   else
#     mkdir -p ${ZIM_HOME} && wget -nv -O ${ZIM_HOME}/zimfw.zsh \
#         https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
#   fi
# fi
# # Install missing modules, and update ${ZIM_HOME}/init.zsh if missing or outdated.
# if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZDOTDIR:-${HOME}}/.zimrc ]]; then
#   source ${ZIM_HOME}/zimfw.zsh init -q
# fi
# # Initialize modules.
# source ${ZIM_HOME}/init.zsh
#
# # ------------------------------
# # Post-init module configuration
# # ------------------------------
#
# #
# # zsh-history-substring-search
# #
#
# zmodload -F zsh/terminfo +p:terminfo
# # Bind ^[[A/^[[B manually so up/down works both before and after zle-line-init
# for key ('^[[A' '^P' ${terminfo[kcuu1]}) bindkey ${key} history-substring-search-up
# for key ('^[[B' '^N' ${terminfo[kcud1]}) bindkey ${key} history-substring-search-down
# for key ('k') bindkey -M vicmd ${key} history-substring-search-up
# for key ('j') bindkey -M vicmd ${key} history-substring-search-down
# unset key
# # }}} End configuration added by Zim install

# Define colors
autoload -U colors && colors
setopt prompt_subst

# Set colors for user and directory
USER_COLOR="%F{green}"
DIR_COLOR="%F{blue}"
DATE_COLOR="%F{red}"
CONDA_COLOR="%F{magenta}"
PROMPT_COLOR="%F{cyan}"
RESET_COLOR="%f"

export LEFT_WIDTH_PERCENT=40
function getLeftWidth() { 
  echo $(( ${COLUMNS} * LEFT_WIDTH_PERCENT / 100 )) 
}


leftWidth='$(getLeftWidth)'

PROMPT=$'\n'
PROMPT+="$DATE_COLOR$RESET_COLOR  %D{%Y/%m/%d - %a} %* - $USER_COLOR%n@%m$RESET_COLOR"
PROMPT+=$'\n'
PROMPT+="$DIR_COLOR  %${COLUMNS-20}<…<%~%<<$RESET_COLOR $CONDA_COLOR$CONDA_DEFAULT_ENV$RESET_COLOR"
PROMPT+=$'\n'
PROMPT+="$PROMPT_COLOR→ $RESET_COLOR"

# Refresh the prompt
autoload -Uz promptinit && promptinit



#=====================================
# Powerlevel10k setup
#=====================================

# # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# # Initialization code that may require console input (password prompts, [y/n]
# # confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi
#
# # clone and install p10k if not installed
# if [ ! -d ~/powerlevel10k ]; then
#   git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
# fi
# source ~/powerlevel10k/powerlevel10k.zsh-theme
#
# if [ ! -d ~/.zsh/zsh-syntax-highlighting ]; then
#   git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
# fi
# source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
#
# # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
# [[ ! -f ~/dotfiles/zsh/.p10k.zsh ]] || source ~/dotfiles/zsh/.p10k.zsh

#=====================================
# Environment Managers
#=====================================

# For NVM setup
export NVM_DIR="$HOME/.nvm"
if [[ "$OSTYPE" == "darwin"* ]]; then
  nvm_prefix=$(brew --prefix nvm)
else
  nvm_prefix="${HOME}/.nvm"
fi

source "${nvm_prefix}/nvm.sh"
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/inwon/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
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
# <<< conda initialize <<<

#=====================================
# CUSTOM Settings
#=====================================

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# add my preferred local path (for neovim, lazygit etc.), docker sock 
export PATH="$HOME/.local/bin:$PATH:$HOME/.docker/bin"

# Custom aliases
alias code="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"
alias latex="latexmk -bibtex -pdf -pvc -output-directory=.cache -quiet -silent"

alias ls="ls --color"


export FZF_DEFAULT_OPTS='--height=40% --preview="cat {}" --preview-window=right:50%:wrap'

edit_command_line() {
	# Create a temporary file
	local TMP_FILE=$(mktemp)

	# Save current command line to the temporary file
	echo "$READLINE_LINE" >"$TMP_FILE"

	# Open vim to edit the command line
	nvim "$TMP_FILE"

	# Set the command line to the modified contents of the temporary file
	READLINE_LINE=$(cat "$TMP_FILE")
	READLINE_POINT=${#READLINE_LINE} # Move the cursor to the end of the line

	# Clean up
	rm "$TMP_FILE"
}

autoload -z edit-command-line && zle -N edit-command-line

export KEYTIMEOUT=1
set -o vi
export EDITOR=nvim
bindkey "^E" edit-command-line  

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# OS Specific stuff
if [[ "$OSTYPE" == "darwin"* ]]; then
  export HOMEBREW_NO_AUTO_UPDATE=true
  # rebind ssh to kitten for mac
  alias s='kitten ssh'
  # add wezterm to path if it exists
  if [ -d /Applications/WezTerm.app ]; then
    PATH="$PATH:/Applications/WezTerm.app/Contents/MacOS"
  fi
fi

if [ -n "${ZSH_DEBUGRC+1}" ]; then
    zprof
fi
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

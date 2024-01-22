# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# clone and install p10k if not installed
if [ ! -d ~/powerlevel10k ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
fi
source ~/powerlevel10k/powerlevel10k.zsh-theme

if [ ! -d ~/.zsh/zsh-autosuggestions ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
fi
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

if [ ! -d ~/.zsh/zsh-syntax-highlighting ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
fi
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

autoload -Uz compinit && compinit

# For case-insensitive tab completion
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'

# for highlighting tab selection
zstyle ':completion:*' menu select

# for completion of directory names
zstyle -e ':completion:*' special-dirs '[[ $PREFIX = (../)#(|.|..) ]] && reply=(..)'

# For NVM setup
export NVM_DIR=~/.nvm
source $(brew --prefix nvm)/nvm.sh

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='mvim'
fi

export HOMEBREW_NO_AUTO_UPDATE=true

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

# add my preferred local path (for neovim, lazygit etc.)
export PATH="$HOME/.local/bin:$PATH"

# symlink for docker sock
export PATH="$PATH:$HOME/.docker/bin"

# for using yarn global packages
export PATH="$PATH:$(yarn global bin)"

# Custom aliases
alias code="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"
alias latex="latexmk -bibtex -pdf -pvc -output-directory=.cache -quiet -silent"

# Add wezterm if it exists
if [ -d /Applications/WezTerm.app ]; then
  PATH="$PATH:/Applications/WezTerm.app/Contents/MacOS"
fi



# export FZF_DEFAULT_OPTS='--height=40% --preview="cat {}" --preview-window=right:60%:wrap'

set -o vi
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/dotfiles/zsh/.p10k.zsh ]] || source ~/dotfiles/zsh/.p10k.zsh

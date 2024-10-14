# Setup fzf
# ---------
if [[ ! "$PATH" == *$HOME/.fzf-x86/bin* ]]; then
  PATH="${PATH:+${PATH}:}$HOME/.fzf-x86/bin"
fi

eval "$(fzf --bash)"

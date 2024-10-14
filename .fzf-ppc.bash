# Setup fzf
# ---------
if [[ ! "$PATH" == *$HOME/.fzf-ppc/bin* ]]; then
  PATH="${PATH:+${PATH}:}$HOME/.fzf-ppc/bin"
fi

eval "$(fzf --bash)"

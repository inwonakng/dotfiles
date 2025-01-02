# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

if [ -f ~/.bash_utils/prompt ]; then
	. ~/.bash_utils/prompt
fi

if [ -f "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

if [ -f "$HOME/.config/ripgrep/config" ]; then
  export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"
fi

if [ -f "$HOME/.bash_utils/completions/git.bash" ]; then
  . "$HOME/.bash_utils/completions/git.bash"
fi

if [ -f "$HOME/.bash_utils/completions/slurm.bash" ]; then
  . "$HOME/.bash_utils/completions/slurm.bash"
fi

# if installed, overwrite cd
if command -v "zoxide" >/dev/null 2>&1; then
  eval "$(zoxide init bash --cmd cd)"
fi

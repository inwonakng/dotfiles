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

if [ -f "$HOME/.bash_utils/completions/python-modules.bash" ]; then
    . "$HOME/.bash_utils/completions/python-modules.bash"
fi

# if installed, overwrite cd
if command -v "zoxide" >/dev/null 2>&1; then
    eval "$(zoxide init bash --cmd cd)"
    alias z="cd"
    alias zi="cdi"
fi

export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"
export AICHAT_CONFIG_DIR="$HOME/.config/aichat"

function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

alias g="lazygit"

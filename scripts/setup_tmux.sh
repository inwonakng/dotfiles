# copy over to .config
mkdir -p $HOME/.config
ln -snf $HOME/dotfiles/tmux $HOME/.config/tmux

# manually control catpuccin -- some issues with TPM
mkdir -p $HOME/.config/tmux/plugins/catppuccin
git clone https://github.com/catppuccin/tmux.git $HOME/.config/tmux/plugins/catppuccin/tmux


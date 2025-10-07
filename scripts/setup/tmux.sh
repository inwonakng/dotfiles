# copy over to .config
mkdir -p $HOME/.config
ln -snf $HOME/dotfiles/tmux $HOME/.config/tmux
ln -snf $HOME/dotfiles/tmux/tmux.conf.remote $HOME/.config/tmux/tmux.conf

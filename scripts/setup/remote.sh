# bash stuff
ln -snf ~/dotfiles/bash/bashrc/remote.sh ~/.bashrc
ln -snf ~/dotfiles/bash/.bash_profile ~/.bash_profile
ln -snf ~/dotfiles/bash/utils ~/.bash_utils

# vim and tmux
mkdir -p ~/.config
ln -snf ~/dotfiles/vim ~/.vim
ln -snf ~/dotfiles/tmux ~/.config/tmux
ln -f ~/dotfiles/tmux/tmux.conf.remote ~/.config/tmux/tmux.conf
ln -snf ~/dotfiles/conda/.condarc ~/
ln -snf ~/dotfiles/.inputrc ~/

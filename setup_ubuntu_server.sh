# files
ln -sf ~/dotfiles/bash/remote/.bashrc ~/.bashrc;
ln -sf ~/dotfiles/bash/.bash_profile ~/.bash_profile;
ln -sf ~/dotfiles/conda/.condarc ~/.condarc;
ln -sf ~/dotfiles/.fdignore ~/.fdignore;

mkdir -p ~/.config

# folders
ln -snf ~/dotfiles/bash/.bash_utils ~/.bash_utils;
ln -snf ~/dotfiles/ipython ~/.ipython;
ln -snf ~/dotfiles/vim ~/.vim;
ln -snf ~/dotfiles/tmux ~/.config/tmux;

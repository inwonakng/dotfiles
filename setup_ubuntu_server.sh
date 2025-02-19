# files
ln -sf ~/dotfiles/bash/remote/.bashrc ~/.bashrc;
ln -sf ~/dotfiles/bash/.bash_profile ~/.bash_profile;
ln -sf ~/dotfiles/.tmux.conf ~/.tmux.conf;
ln -sf ~/dotfiles/conda/.condarc ~/.condarc;

mkdir -p ~/.config

# folders
ln -snf ~/dotfiles/bash/.bash_utils ~/.bash_utils;
ln -snf ~/dotfiles/.ipython ~/.ipython;
ln -snf ~/dotfiles/.vim ~/.vim;
ln -snf ~/dotfiles/tmux ~/.config/tmux;

# bash scripts/install_conda.sh;
# bash ~/dotfiles/scripts/setup_pynvim.sh;
# bash ~/dotfiles/scripts/install_fzf.sh;
# bash ~/dotfiles/scripts/install_using_conda.sh --program git --version 2.40.1;
# bash ~/dotfiles/scripts/install_using_conda.sh --program tmux --version 3.3a;

# files
ln -sf ~/dotfiles/cci/.bashrc ~/.bashrc;
ln -sf ~/dotfiles/.vimrc ~/.vimrc;
ln -sf ~/dotfiles/.tmux.conf ~/.tmux.conf;

# folders
ln -snf ~/dotfiles/.ipython ~/.ipython;
ln -snf ~/dotfiles/nvim ~/.config/nvim;

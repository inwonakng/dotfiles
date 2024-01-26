bash scripts/install_conda.sh;
bash scripts/setup_pynvim.sh;
bash scripts/install_using_conda.sh --program git --version 2.40.1;
bash scripts/install_using_conda.sh --program tmux --version 3.3a;
bash scripts/install_using_conda.sh --program zsh --version 5.9;

# files
ln -sf ~/dotfiles/ubuntu-server/.bashrc ~/.bashrc;
ln -sf ~/dotfiles/.vimrc ~/.vimrc;
ln -sf ~/dotfiles/.tmux.conf ~/.tmux.conf;

# folders
ln -snf ~/dotfiles/.ipython ~/.ipython;
ln -snf ~/dotfiles/nvim-lite ~/.config/nvim;

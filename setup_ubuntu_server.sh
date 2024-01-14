bash scripts/conda.sh
bash scripts/pynvim.sh

# files
ln -sf ~/dotfiles/ubuntu-server/.bashrc ~/.bashrc
ln -sf ~/dotfiles/.vimrc ~/.vimrc
ln -sf ~/dotfiles/.tmux.conf ~/.tmux.conf

# folders
ln -snf ~/dotfiles/.ipython ~/.ipython
ln -snf ~/dotfiles/nvim-lite ~/.config/nvim

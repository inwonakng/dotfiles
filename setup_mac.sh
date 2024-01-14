bash scripts/conda.sh

# files
ln -sf ~/dotfiles/osx/.zshrc ~/.zshrc
ln -sf ~/dotfiles/osx/.zshenv ~/.zshenv
ln -sf ~/dotfiles/osx/.latexmkrc ~/.latexmkrc
ln -sf ~/dotfiles/osx/.hammerspoon/init.lua ~/.hammerspoon/init.lua
ln -sf ~/dotfiles/.vimrc ~/.vimrc
ln -sf ~/dotfiles/.tmux.conf ~/.tmux.conf

# folders
ln -snf ~/dotfiles/.ipython ~/.ipython
ln -snf ~/dotfiles/nvim ~/.config/nvim
ln -snf ~/dotfiles/wezterm ~/.config/wezterm

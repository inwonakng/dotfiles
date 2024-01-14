bash install/conda.sh

# files
ln -sf ~/dotfiles/osx/.zshrc ~/.zshrc
ln -sf ~/dotfiles/osx/.zshenv ~/.zshenv
ln -sf ~/dotfiles/osx/.latexmkrc ~/.latexmkrc
ln -sf ~/dotfiles/osx/.hammerspoon/init.lua ~/.hammerspoon/init.lua
ln -sf ~/dotfiles/common/.vimrc ~/.vimrc
ln -sf ~/dotfiles/common/.tmux.conf ~/.tmux.conf

# folders
ln -snf ~/dotfiles/common/.ipython ~/.ipython
ln -snf ~/dotfiles/common/nvim ~/.config/nvim
ln -snf ~/dotfiles/common/wezterm ~/.config/wezterm

bash ~/dotfiles/scripts/install_conda.sh
bash ~/dotfiles/nvim/install-full.sh

# folders
ln -snf ~/dotfiles/.ipython ~/.ipython
ln -snf ~/dotfiles/wezterm ~/.config/wezterm
ln -snf ~/dotfiles/lazygit "~/Library/Application Support/lazygit"

# files
ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc
ln -sf ~/dotfiles/zsh/.zimrc ~/.zimrc
ln -sf ~/dotfiles/zsh/.zshenv ~/.zshenv
ln -sf ~/dotfiles/osx/.latexmkrc ~/.latexmkrc
ln -sf ~/dotfiles/osx/.hammerspoon/init.lua ~/.hammerspoon/init.lua
ln -sf ~/dotfiles/.vimrc ~/.vimrc
ln -sf ~/dotfiles/.tmux.conf ~/.tmux.conf
ln -sf ~/dotfiles/kitty/kitty-mac.conf ~/.config/kitty/kitty.conf
ln -sf ~/dotfiles/ripgrep/config ~/.config/ripgrep/config

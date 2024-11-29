
# open code and repl
WEZTERM_STARTUP_MODE=editor wezterm
WEZTERM_STARTUP_MODE=interactive wezterm

# open notes 
WEZTERM_STARTUP_MODE=notes wezterm

# send the last one to workspace N for notes


# NOTES_DIR="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/work/"
# # Replace slashes with % for the swap file pattern
# swap_pattern=$(echo "$NOTES_DIR" | sed 's/\//%/g')
# swap_files=$(find ~/.local/state/nvim/swap -type f -name "$swap_pattern*.swp")
#
# # Check if any swap files were found
# if [ -z "$swap_files" ]; then
#   # No swap files found, open Neovim in the target directory
#   # wezterm cli spawn --cwd $NOTES_DIR --new-window -- source ~/.nvm/nvm.sh && nvim -c "lua require('persistence').load()"
#   # wezterm cli spawn --cwd $NOTES_DIR --new-window -- bash ~/dotfiles/scripts/shortcuts/notes_nvim.sh
#   WEZTERM_STARTUP_MODE=notes wezterm
# fi
#
# NOTES_DIR="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal"
# # Replace slashes with % for the swap file pattern
# swap_pattern=$(echo "$NOTES_DIR" | sed 's/\//%/g')
# swap_files=$(find ~/.local/state/nvim/swap -type f -name "$swap_pattern*.swp")
#
# # Check if any swap files were found
# if [ -z "$swap_files" ]; then
#   # No swap files found, open Neovim in the target directory
#   # wezterm cli spawn --cwd $NOTES_DIR --new-window -- source ~/.nvm/nvm.sh && nvim -c "lua require('persistence').load()"
#   wezterm cli spawn --cwd $NOTES_DIR --new-window -- bash ~/dotfiles/scripts/shortcuts/notes_nvim.sh
# fi

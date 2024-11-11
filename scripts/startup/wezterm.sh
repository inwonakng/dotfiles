NOTES_DIR="$HOME/Documents/notes/"
# Replace slashes with % for the swap file pattern
swap_pattern=$(echo "$NOTES_DIR" | sed 's/\//%/g')
swap_files=$(find ~/.local/state/nvim/swap -type f -name "$swap_pattern*.swp")

# Check if any swap files were found
if [ -z "$swap_files" ]; then
  # No swap files found, open Neovim in the target directory
  wezterm cli spawn --cwd $NOTES_DIR --new-window -- nvim -c "lua require('persistence').load()"
fi

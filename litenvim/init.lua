require("globals")
require("config.options")

require("plugins")

vim.cmd.colorscheme("catppuccin")

-- additional settings. Separated like how lazyvim does it.
require("config.keymaps")
require("config.commands")
require("config.autocmds")
require("config.lsp")
require("config.folds")
require("ui")


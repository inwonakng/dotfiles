-- Capture startup mode before plugins or session restoration change the argument list.
vim.g.project_mode = vim.fn.argc() == 0 and vim.env.IS_TEMP_SESSION ~= "1"

vim.pack.add({ "https://github.com/inwonakng/nvim-extras" })

require("globals")
require("config.options")

require("plugins")

-- additional settings. Separated like how lazyvim does it.
require("config.keymaps")
require("config.commands")
require("config.autocmds")
require("config.lsp")
require("config.folds")
require("ui")

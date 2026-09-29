local extras_dev = vim.fn.expand("~/.local/share/nvim-dev/nvim-extras")
if vim.fn.isdirectory(extras_dev) == 1 then
	vim.opt.runtimepath:prepend(extras_dev)
else
	vim.pack.add({ "https://github.com/inwonakng/nvim-extras" })
end

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

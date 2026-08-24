local config_root = vim.uv.fs_realpath(vim.fn.stdpath("config"))
if config_root then
	vim.opt.runtimepath:prepend(vim.fs.joinpath(vim.fs.dirname(config_root), "custom-nvim-modules"))
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

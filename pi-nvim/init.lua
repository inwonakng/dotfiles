local config_root = vim.uv.fs_realpath(vim.fn.stdpath("config"))
if config_root then
	vim.opt.runtimepath:prepend(vim.fs.joinpath(vim.fs.dirname(config_root), "custom-nvim-modules"))
end

require("config.options")
require("config.plugins")
require("config.theme")
require("config.which-key")
require("config.fzf")
require("config.treesitter")
require("config.completion")
require("config.markdown")
require("config.pi")
require("config.oil")
require("config.keymaps")
require("config.commands")

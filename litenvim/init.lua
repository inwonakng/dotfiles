local extras_root = vim.env.NVIM_EXTRAS_PATH
if extras_root and extras_root ~= "" then
	extras_root = vim.fs.normalize(vim.fn.expand(extras_root))
	if vim.fn.isdirectory(extras_root) == 0 then
		error("NVIM_EXTRAS_PATH is not a directory: " .. extras_root)
	end
	vim.opt.runtimepath:prepend(extras_root)
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

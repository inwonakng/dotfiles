vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.laststatus = 2
vim.opt.showmode = false
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.termguicolors = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.hidden = true

require("pi-integration").setup({
	binary = vim.env.PI_BINARY or "pi",
	provider = vim.env.PI_PROVIDER,
	model = vim.env.PI_MODEL,
	session_dir = vim.env.PI_SESSION_DIR,
	show_thinking = false,
})
require("config.keymaps")

-- startup commands
vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		require("pi-integration").open()
	end,
})

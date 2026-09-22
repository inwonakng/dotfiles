-- latex is special
vim.api.nvim_create_autocmd({ "FileType" }, {
	pattern = { "bib", "tex" },
	callback = function()
		vim.opt_local.conceallevel = 0
		vim.opt_local.wrap = true
		vim.bo.shiftwidth = 2
		vim.bo.tabstop = 2
	end,
})

-- filetypes that use 2 spaces for tab
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "lua", "javascript", "typescript", "json", "html", "css", "scss", "yaml", "markdown" },
	callback = function()
		vim.bo.expandtab = true
		vim.bo.shiftwidth = 2
		vim.bo.tabstop = 2
		vim.bo.softtabstop = 2
	end,
})

-- turn off wrap for certain filetypes
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "python", "lua" }, -- List the file types here
	callback = function()
		vim.opt_local.wrap = false
	end,
})

-- Obsidian with hledger. If in this directory, render as ledger filetype
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	group = vim.api.nvim_create_augroup("md_ledger", { clear = true }),
	pattern = {
		vim.env.HOME .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal/finance/journals/**.md",
		vim.env.HOME .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal/finance/journals/**.journal",
	},
	callback = function()
		vim.bo.filetype = "ledger"
		vim.opt_local.wrap = false
		vim.bo.shiftwidth = 4
		vim.bo.tabstop = 4
	end,
})

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
	callback = function()
		local highlight_yank = vim.hl.hl_op or vim.hl.on_yank
		highlight_yank()
	end,
})

-- numi calculator scratch buffer
vim.filetype.add({ extension = { numi = "numi" } })
vim.api.nvim_create_autocmd("FileType", {
	pattern = "numi",
	callback = function()
		require("utils.calc-mode").setup(vim.api.nvim_get_current_buf())
	end,
})

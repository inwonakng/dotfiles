vim.g.mkdp_filetypes = { "markdown" }

vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	once = true,
	callback = function()
		vim.pack.add({ "https://github.com/iamcco/markdown-preview.nvim" })
	end,
})

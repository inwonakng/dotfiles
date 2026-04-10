vim.g.mkdp_filetypes = { "markdown" }
vim.pack.add({ "https://github.com/iamcco/markdown-preview.nvim" })

vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	once = true,
	callback = function()
		vim.fn["mkdp#util#install"]()
	end,
})

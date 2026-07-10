local ok_treesitter, treesitter = pcall(require, "nvim-treesitter.config")
if ok_treesitter then
	treesitter.setup({
		ensure_installed = {
			"markdown",
			"markdown_inline",
			"yaml",
		},
		highlight = {
			enable = true,
		},
	})
else
	vim.notify("nvim-treesitter unavailable; markdown injections may be missing", vim.log.levels.WARN)
end

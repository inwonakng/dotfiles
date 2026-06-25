local ok_which_key, which_key = pcall(require, "which-key")
if ok_which_key then
	which_key.setup({})
	which_key.add({
		{ "<leader><tab>", group = "tabs" },
		{ "<leader>b", group = "buffers" },
		{ "<leader>i", group = "insert" },
		{ "<leader>p", group = "pi" },
		{ "<leader>u", group = "ui" },
		{ "<leader>w", group = "windows" },
		{ "<leader>y", group = "yank" },
	})
else
	vim.notify("which-key unavailable", vim.log.levels.WARN)
end

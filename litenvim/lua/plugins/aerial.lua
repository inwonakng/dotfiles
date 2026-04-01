vim.pack.add({ "https://github.com/stevearc/aerial.nvim" })

require("aerial").setup({
	attach_mode = "global",
	backends = { "lsp", "treesitter", "markdown", "man" },
	show_guides = true,
	layout = {
		resize_to_content = false,
		max_width = { 0.3 },
		-- width = nil,
		min_width = 30,
		win_opts = {
			winhl = "Normal:NormalFloat,FloatBorder:NormalFloat,SignColumn:SignColumnSB",
			signcolumn = "yes",
			statuscolumn = " ",
		},
	},
	guides = {
		mid_item = "├╴",
		last_item = "└╴",
		nested_top = "│ ",
		whitespace = "  ",
	},
})

vim.keymap.set("n", "<leader>cs", "<cmd>AerialToggle<cr>", { desc = "Aerial (Symbols)" })
vim.keymap.set("n", "<leader>co", "<cmd>AerialOpenAll<cr>", { desc = "Aerial (All)" })

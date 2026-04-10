vim.pack.add({ "https://github.com/rachartier/tiny-inline-diagnostic.nvim" })

require("tiny-inline-diagnostic").setup({
	options = {
		show_source = { enabled = true },
		show_code = true,
		use_icons_from_diagnostic = true,
		show_severity = true,
		add_messages = {
			display_count = true,
		},
		multilines = {
			enabled = true,
		},
	},
})

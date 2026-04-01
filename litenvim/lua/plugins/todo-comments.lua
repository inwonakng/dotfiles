vim.pack.add({
	"https://github.com/folke/todo-comments.nvim",
})

require("todo-comments").setup({
	keywords = {
		FIX = {
			icon = " ", -- icon used for the sign, and in search results
			color = "error", -- can be a hex color, or a named color (see below)
			alt = { "FIXME", "BUG", "FIXIT", "ISSUE" }, -- a set of other keywords that all map to this FIX keywords
		},
		TODO = { icon = " ", color = "info" },
		HACK = { icon = " ", color = "warning" },
		WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
		PERF = { icon = " ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
		NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
		TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
	},
	colors = {
		error = { "DiagnosticError", "ErrorMsg", "#DC2626" },
		warning = { "DiagnosticWarn", "WarningMsg", "#FBBF24" },
		info = { "DiagnosticInfo", "#2563EB" },
		hint = { "DiagnosticHint", "#10B981" },
		default = { "Identifier", "#7C3AED" },
		test = { "Identifier", "#FF00FF" },
	},
})

vim.keymap.set("n", "<leader>st", function()
	require("todo-comments.fzf").todo({ prompt = "Search Tags " })
end, { desc = "Search todo comments" })

vim.keymap.set("n", "<leader>sT", function()
	require("todo-comments.fzf").todo({ keywords = { "TODO", "FIX", "FIXME" }, prompt = "Search Todos " })
end, { desc = "Search TODO/FIX/FIXME comments" })

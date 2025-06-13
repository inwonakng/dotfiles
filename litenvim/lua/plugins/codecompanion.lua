return {
	"olimorris/codecompanion.nvim",
	opts = {
		adapters = {
			gemini = function()
				return require("codecompanion.adapters").extend("gemini", {
					env = {
						api_key = "cmd: cat ~/.keys/gemini.txt",
					},
				})
			end,
		},
		strategies = {
			chat = {
				adapter = {
					name = "gemini",
					model = "gemini-2.5-pro-preview-06-05",
				},
			},
		},
		opts = {
			log_level = "info",
		},
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
}

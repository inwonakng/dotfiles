vim.api.nvim_create_autocmd("Filetype", {
	pattern = { "markdown", "codecompanion" },
	once = true,
	callback = function()
		vim.pack.add({ "https://github.com/MeanderingProgrammer/render-markdown.nvim" })
		require("render-markdown").setup({
			heading = {
				sign = false,
				-- icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
			},
			callout = {
				definition = { raw = "[!DEFINITION]", rendered = " Definition", highlight = "RenderMarkdownInfo" },
				motivation = { raw = "[!MOTIVATION]", rendered = " Motivation", highlight = "RenderMarkdownInfo" },
				intuition = { raw = "[!INTUITION]", rendered = " Intuition", highlight = "RenderMarkdownSuccess" },
				setting = { raw = "[!SETTING]", rendered = "󱊍 Setting", highlight = "RenderMarkdownHint" },
				image = { raw = "[!IMAGE]", rendered = " Image", highlight = "RenderMarkdownInfo" },
				table = { raw = "[!TABLE]", rendered = " Table", highlight = "RenderMarkdownInfo" },
			},
			latex = { enabled = true },
		})
	end,
})

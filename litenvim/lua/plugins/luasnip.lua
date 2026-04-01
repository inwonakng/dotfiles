vim.pack.add({
	"https://github.com/L3MON4D3/LuaSnip",
	"https://github.com/rafamadriz/friendly-snippets",
})

local vscode_loader = require("luasnip.loaders.from_vscode")

require("luasnip").setup({
	history = true,
	delete_check_events = "TextChanged",
})

vscode_loader.lazy_load({ paths = { "./snippets" } })
vscode_loader.lazy_load()

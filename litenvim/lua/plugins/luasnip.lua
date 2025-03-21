return {
	"L3MON4D3/LuaSnip",
	lazy = true,
	dependencies = { "rafamadriz/friendly-snippets" },
	opts = function(_, opts)
		local ls = require("luasnip")
		local luasnip_loader = require("luasnip.loaders.from_vscode")
		luasnip_loader.lazy_load({ paths = { "./snippets" } })
		luasnip_loader.lazy_load()
		opts.history = true
		opts.delete_check_events = "TextChanged"
		return opts
	end,
}

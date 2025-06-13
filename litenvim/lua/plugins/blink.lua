return {
	"saghen/blink.cmp",
	dependencies = {
		"rafamadriz/friendly-snippets",
		-- credit: https://www.reddit.com/r/neovim/comments/1invqwg/blinkcmp_luasnip_autosnippets_and_cmpvimtex/
		{
			"micangl/cmp-vimtex",
			dependencies = {
				{
					"saghen/blink.compat",
					version = "*",
					lazy = true,
					opts = {},
				},
			},
		},
	},
	version = "*",
	build = "cargo build --release",

	---@module 'blink.cmp'
	---@type blink.cmp.Config
	opts = {
		cmdline = {
			enabled = false,
		},
		keymap = {
			["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
			["<C-e>"] = { "hide", "fallback" },
			["<CR>"] = { "accept", "fallback" },
			["<Tab>"] = { "snippet_forward", "fallback" },
			["<S-Tab>"] = { "snippet_backward", "fallback" },
			["<Up>"] = { "select_prev", "fallback" },
			["<Down>"] = { "select_next", "fallback" },
			["<C-p>"] = { "select_prev", "fallback" },
			["<C-n>"] = { "select_next", "fallback" },
			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
			["<C-k>"] = { "show_signature", "hide_signature", "fallback" },
		},
		appearance = {
			use_nvim_cmp_as_default = true,
			nerd_font_variant = "mono",
		},
		completion = {
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 500,
			},
		},
		sources = {
			default = {
				"lsp",
				"path",
				"snippets",
				"buffer",
				"markdown",
				"vimtex",
			},
			per_filetype = {
				codecompanion = { "codecompanion" },
			},
			providers = {
				markdown = {
					name = "RenderMarkdown",
					module = "render-markdown.integ.blink",
					fallbacks = { "lsp" },
				},
				vimtex = {
					name = "vimtex",
					module = "blink.compat.source",
					score_offset = 100,
				},
				path = {
					opts = {
						get_cwd = function(_)
							return vim.fn.getcwd()
						end,
					},
				},
			},
		},
	},
	opts_extend = { "sources.default" },
}

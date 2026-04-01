vim.pack.add({
	"https://github.com/saghen/blink.cmp",
	"https://github.com/rafamadriz/friendly-snippets",
	"https://github.com/micangl/cmp-vimtex",
	"https://github.com/saghen/blink.compat",
})

vim.api.nvim_create_user_command("BlinkBuild", function()
	require("blink.cmp.fuzzy.build").build()
end, { desc = "Build blink.cmp Rust fuzzy library" })

require("blink.cmp").setup({
	cmdline = {
		enabled = false,
	},
	keymap = {
		["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
		["<C-e>"] = { "hide", "fallback" },
		["<CR>"] = { "accept", "fallback" },
		-- ["<Tab>"] = { "snippet_forward", "fallback" },
		["<Tab>"] = {
			"snippet_forward",
			function() -- sidekick next edit suggestion
				return require("sidekick").nes_jump_or_apply()
			end,
			-- function() -- if you are using Neovim's native inline completions
			-- 	return vim.lsp.inline_completion.get()
			-- end,
			"fallback",
		},
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
			-- "markdown",
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
})

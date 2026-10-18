vim.pack.add({
	"https://github.com/saghen/blink.cmp",
	"https://github.com/rafamadriz/friendly-snippets",
	"https://github.com/micangl/cmp-vimtex",
	"https://github.com/saghen/blink.compat",
	"https://github.com/saghen/blink.lib",
})

local cmp = require("blink.cmp")
cmp.build():pwait()

local default_label_highlight = require("blink.cmp.config").completion.menu.draw.components.label.highlight

cmp.setup({
	term = { enabled = false },
	cmdline = {
		enabled = false,
	},
	keymap = {
		["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
		["<Esc>"] = {
			function(cmp)
				cmp.cancel()
				return false
			end,
			"fallback",
		},
		["<C-e>"] = { "cancel", "fallback" },
		["<CR>"] = { "accept", "fallback" },
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
		menu = {
			draw = {
				components = {
					label = {
						highlight = function(ctx)
							if ctx.source_id == "hledger_accounts" then
								local group = ctx.item.data.hledger_component and "HledgerCmpComponent" or "HledgerCmpAccount"
								return { { 0, #ctx.label, group = group, priority = 20000 } }
							end
							return default_label_highlight(ctx)
						end,
					},
				},
			},
		},
		documentation = {
			auto_show = true,
			auto_show_delay_ms = 500,
		},
	},
	sources = {
		transform_items = function(ctx, items)
			if vim.bo[ctx.bufnr].filetype == "ledger" and require("completion.hledger").in_account(ctx) then
				return vim.tbl_filter(function(item)
					return item.source_id == "hledger_accounts"
				end, items)
			end
			return items
		end,
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
			ledger = { inherit_defaults = true, "hledger_accounts", "omni" },
		},
		providers = {
			hledger_accounts = {
				name = "Hledger Accounts",
				module = "completion.hledger",
				async = true,
			},
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

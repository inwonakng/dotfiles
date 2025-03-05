return {
	"neovim/nvim-lspconfig",
	dependencies = {
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
		"saghen/blink.cmp",
	},
	opts = function()
		local ret = {
			codelens = {
				enabled = false,
			},
			diagnostics = {
				underline = false,
				signs = true,
				virtual_text = false,
				float = {
					show_header = true,
					source = "always",
					border = "rounded",
					focusable = true,
				},
				update_in_insert = false, -- default to false
				severity_sort = false, -- default to false
			},
			inlay_hints = {
				enabled = false,
			},
			servers = {
				basedpyright = {
					analysis = {
						diagnosticMode = "off",
					},
				},
				texlab = {
					keys = {
						{ "<Leader>K", "<plug>(vimtex-doc-package)", desc = "Vimtex Docs", silent = true },
					},
				},
				lua_ls = {
					settings = {
						Lua = {
							format = { enable = true, defaultConfig = { indent_style = "space", indent_size = "4" } },
							workspace = {
								checkThirdParty = false,
							},
							codeLens = {
								enable = true,
							},
							completion = {
								callSnippet = "Replace",
							},
							doc = {
								privateName = { "^_" },
							},
							hint = {
								enable = true,
								setType = false,
								paramType = true,
								paramName = "Disable",
								semicolon = "Disable",
								arrayIndex = "Disable",
							},
						},
					},
				},
				jsonls = {
					settings = {
						json = {
							format = {
								enable = true,
							},
							validate = { enable = true },
						},
					},
				},
				marksman = {},
			},
		}
		return ret
	end,
	config = function(_, opts)
		-- apparently I still need to do this..
		vim.diagnostic.config(opts.diagnostics)
		require("mason").setup()
		-- register mason
		require("mason-lspconfig").setup({
			ensure_installed = vim.tbl_keys(opts.servers),
		})
		require("mason-lspconfig").setup_handlers({
			function(server_name)
				require("lspconfig")[server_name].setup(vim.tbl_deep_extend("force", {
					on_attach = function(client, bufnr)
						-- your custom on_attach code
					end,
					capabilities = {}, -- your capabilities (or nil)
				}, opts.servers[server_name] or {}))
			end,
		})
		-- regstier blink.cmp
		for server, config in pairs(opts.servers) do
			config.capabilities = require("blink.cmp").get_lsp_capabilities(config.capabilities)
			require("lspconfig")[server].setup(config)
		end
	end,
	keys = {
		{
			"<leader>cd",
			function()
				vim.diagnostic.open_float()
			end,
      desc="Show Diagnostic",
		},
	},
}

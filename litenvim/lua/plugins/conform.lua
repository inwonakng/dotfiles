return {
	"stevearc/conform.nvim",
	lazy = true,
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>cf",
			function()
				require("conform").format({ async = true })
			end,
			mode = { "n", "v" },
			desc = "Format Code",
		},
		{
			"<leader>cF",
			function()
				require("conform").format({ formatters = { "injected" }, timeout_ms = 3000 })
			end,
			mode = { "n", "v" },
			desc = "Format Injected Langs",
		},
		{
			"<leader>ci",
			function()
				require("conform").format({
					formatters = { "ruff_fix" },
				})
			end,
			mode = { "n", "v" },
			desc = "Clean Imports (Ruff)",
		},
	},
	init = function()
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
	end,
	opts = {
		formatters_by_ft = {
			python = {
				"isort",
				"ruff_fix_keep_imports", -- To fix lint errors. (ruff with argument --fix)
				"ruff_format", -- To run the formatter. (ruff with argument format)
				"docformatter",
			},
			sh = { "shfmt" },
			tex = { "latexindent" },
			html = { "prettier" },
			css = { "prettier" },
			javascript = { "prettier" },
			javascriptreact = { "prettier" },
			typescript = { "prettier" },
			typescriptreact = { "prettier" },
			json = { "prettier" },
			jsonc = { "prettier" },
			yaml = { "prettier" },
			lua = { "stylua" },
			ledger = { "ledger_align" },
			markdown = { "prettier", "markdownlint-cli2", "markdown-toc" },
			["markdown.mdx"] = { "prettier", "markdownlint-cli2", "markdown-toc" },
			toml = { "taplo" },
		},
		formatters = {
			ledger_align = {
				format = function()
					vim.cmd("LedgerAlignBuffer")
					-- Return nil to indicate the buffer was modified in-place
					return nil
				end,
			},
			ruff_fix_keep_imports = {
				command = "ruff",
				args = { "check", "--select", "ALL", "--fix", "--unfixable=F401", "--quiet", "--stdin-filename", "$FILENAME", "-" },
			},
			["markdown-toc"] = {
				condition = function(_, ctx)
					for _, line in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
						if line:find("<!%-%- toc %-%->") then
							return true
						end
					end
				end,
			},
			["markdownlint-cli2"] = {
				condition = function(_, ctx)
					local diag = vim.tbl_filter(function(d)
						return d.source == "markdownlint"
					end, vim.diagnostic.get(ctx.buf))
					return #diag > 0
				end,
			},
		},
	},
}

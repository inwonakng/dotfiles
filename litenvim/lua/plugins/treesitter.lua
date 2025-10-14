return {
	"nvim-treesitter/nvim-treesitter",
	events = { "BufReadPre", "BufNewFile" },
	opts = {
		ensure_installed = {
			"c",
			"lua",
			"vim",
			"vimdoc",
			"query",
			"markdown",
			"markdown_inline",
			"bibtex",
			"latex",
			"ninja",
			"python",
			"ron",
			"rst",
			"toml",
			"typescript",
			"tsx",
			"json",
			"json5",
			"jsonc",
			"yaml",
			"ledger",
			"rust",
			"bash",
			"javascript",
			"ron",
      "kdl",
		},
		highlight = {
			enable = true,
			disable = { "latex" },
		},
		autotag = {
			enable = true,
			filetypes = { "ts", "tsx", "js", "jsx", "mdx", "html" },
		},
		incremental_selection = {
			enable = true,
			keymaps = {
				init_selection = "<C-space>",
				node_incremental = "<C-space>",
				scope_incremental = false,
				node_decremental = "<bs>",
			},
		},
		indent = {
			enable = true,
			-- disable = { "python" },
		},
	},
	-- NOTE: we need to call this!! otherwise the treesitter queries won't be available
	config = function(_, opts)
		require("nvim-treesitter.configs").setup(opts)
	end,
}

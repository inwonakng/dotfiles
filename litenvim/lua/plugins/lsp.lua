return {
	{
		"williamboman/mason.nvim",
		opts = {
			ensure_installed = {
				"ruff",
				"black",
				"isort",
				"shfmt",
				"prettier",
				"stylua",
				"codelldb",
				"markdown-toc",
				"markdownlint",
				"markdownlint-cli2",
			},
		},
		---@param opts MasonSettings | {ensure_installed: string[]}
		config = function(_, opts)
			require("mason").setup(opts)
			local mr = require("mason-registry")
			mr:on("package:install:success", function()
				vim.defer_fn(function()
					-- trigger FileType event to possibly load this newly installed LSP server
					require("lazy.core.handler.event").trigger({
						event = "FileType",
						buf = vim.api.nvim_get_current_buf(),
					})
				end, 100)
			end)
			mr.refresh(function()
				for _, tool in ipairs(opts.ensure_installed) do
					local p = mr.get_package(tool)
					if not p:is_installed() then
						p:install()
					end
				end
			end)
		end,
	},
	{
		"j-hui/fidget.nvim",
		event = "LspAttach",
		opts = {
			progress = {
				suppress_on_insert = true,
				display = {
					done_ttl = 2,
					done_icon = tools.ui.icons.ok,
					progress_icon = {
						pattern = {
							" 󰫃 ",
							" 󰫄 ",
							" 󰫅 ",
							" 󰫆 ",
							" 󰫇 ",
							" 󰫈 ",
						},
					},
					done_style = "NonText",
					group_style = "NonText",
					icon_style = "NonText",
					progress_style = "NonText",
				},
			},
			notification = {
				window = {
					border_hl = "LspCodeLens",
					normal_hl = "LspCodeLens",
					winblend = 30,
					border = "solid",
					relative = "win",
				},
			},
		},
	},
}

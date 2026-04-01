vim.pack.add({
	"https://github.com/williamboman/mason.nvim",
	"https://github.com/j-hui/fidget.nvim",
})

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
}

require("mason").setup(opts)

local mr = require("mason-registry")
mr:on("package:install:success", function()
	vim.defer_fn(function()
		-- trigger FileType event to possibly load this newly installed LSP server
    vim.cmd("doautocmd FileType")
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

vim.api.nvim_create_autocmd("LspAttach", {
	once = true,
	callback = function()
		vim.pack.add({ "https://github.com/j-hui/fidget.nvim" })
		local fidget = require("fidget")
		fidget.setup({
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
		})
	end,
})

vim.pack.add({ "https://github.com/nvim-treesitter/nvim-treesitter" })

local treesitter = require("nvim-treesitter")

local parsers = {
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
	"yaml",
	"ledger",
	"rust",
	"bash",
	"javascript",
	"kdl",
}

-- This is a no-op for parsers that are already installed.
treesitter.install(parsers)

local group = vim.api.nvim_create_augroup("Treesitter", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
	group = group,
	callback = function(args)
		local filetype = vim.bo[args.buf].filetype
		local language = vim.treesitter.language.get_lang(filetype)

		if not language or not vim.treesitter.language.add(language) then
			return
		end

		if language ~= "latex" then
			vim.treesitter.start(args.buf, language)
		end

		vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
	end,
})

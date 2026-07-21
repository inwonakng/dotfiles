-- if some packages need special handling after install/update, do it here
vim.api.nvim_create_autocmd("PackChanged", {
	callback = function(ev)
		local name, kind = ev.data.spec.name, ev.data.kind
		if name == "nvim-treesitter" and kind == "update" then
			if not ev.data.active then
				vim.cmd.packadd("nvim-treesitter")
			end
			vim.cmd("TSUpdate")
		elseif name == "blink.cmp" and (kind == "install" or kind == "update") then
			if not ev.data.active then
				vim.cmd.packadd(name)
			end
			require("blink.cmp.fuzzy.build").build()
		elseif name == "markdown-preview.nvim" and (kind == "install" or kind == "update") then
			local app_dir = vim.fn.stdpath("data") .. "/site/pack/core/opt/markdown-preview.nvim/app"
			vim.fn.jobstart({ "npx", "--yes", "yarn", "install" }, { cwd = app_dir })
		end
	end,
})

-- this is where everyting is enabled
require("plugins.aerial")
require("plugins.blink")
require("plugins.conform")
require("plugins.copilot")
require("plugins.dropbar")
require("plugins.fzf")
require("plugins.gitsigns")
require("plugins.lsp")
require("plugins.luasnip")
require("plugins.markdown-preview")
require("plugins.autopairs")
require("plugins.obsidian")
require("plugins.oil")
require("plugins.persistence")
require("plugins.render-markdown")
require("plugins.todo-comments")
require("plugins.vim-slime")
require("plugins.treesitter")
require("plugins.vimtex")
require("plugins.which-key")
require("plugins.tiny-cmdline")
require("plugins.render-latex")

-- add the rest here
vim.pack.add({
	"https://github.com/MagicDuck/grug-far.nvim",
	"https://github.com/stevearc/overseer.nvim",
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/nvim-tree/nvim-web-devicons",
	"https://github.com/folke/trouble.nvim",
	"https://github.com/ledger/vim-ledger",
	"https://github.com/sindrets/diffview.nvim",
	{ src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
	"https://github.com/hedyhli/outline.nvim",
	"https://github.com/nvim-treesitter/nvim-treesitter-context",
})

require("catppuccin").setup({
	color_overrides = {
		mocha = {
			base = "#14161b",
			mantle = "#14161b",
			crust = "#14161b",
		},
	},
})
vim.cmd.colorscheme("catppuccin")

require("outline").setup({
	preview_window = {
		auto_preview = true,
		open_hover_on_preview = true,
		width = 30, -- Percentage or integer of columns
		min_width = 50,
	},
})

-- keymaps for the one-line plugins.
vim.keymap.set("n", "<leader>sr", "<cmd>GrugFar<cr>", { desc = "Find files with grug-far" })

vim.keymap.set("n", "<leader>ow", "<cmd>OverseerToggle<cr>", { desc = "Task list" })
vim.keymap.set("n", "<leader>or", "<cmd>OverseerRun<cr>", { desc = "Run task" })

vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "Git file history (Diffview)" })
vim.keymap.set("n", "<leader>gv", "<cmd>DiffviewOpen<cr>", { desc = "Open Diffview" })

vim.keymap.set("n", "<leader>cs", "<cmd>Outline<CR>", { desc = "Code Symbols" })

vim.keymap.set("n", "[c", function()
	require("treesitter-context").go_to_context(vim.v.count1)
end, { silent = true })
vim.keymap.set("n", "<leader>uc", "<cmd>TSContext toggle<CR>", { desc = "Toggle Treesitter Context" })

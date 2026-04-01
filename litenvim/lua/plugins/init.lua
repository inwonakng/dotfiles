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
require("plugins.noice")
require("plugins.obsidian")
require("plugins.oil")
require("plugins.persistence")
require("plugins.render-markdown")
require("plugins.sidekick")
require("plugins.todo-comments")
require("plugins.vim-slime")
require("plugins.treesitter")
require("plugins.vimtex")
require("plugins.which-key")

-- add the rest here
vim.pack.add({
	"https://github.com/windwp/nvim-autopairs",
	"https://github.com/MagicDuck/grug-far.nvim",
	"https://github.com/stevearc/overseer.nvim",
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/nvim-tree/nvim-web-devicons",
	"https://github.com/folke/trouble.nvim",
	"https://github.com/ledger/vim-ledger",
})

-- keymaps for the one-line plugins.
vim.keymap.set("n", "<leader>sr", "<cmd>GrugFar<cr>", { desc = "Find files with grug-far" })

vim.keymap.set("n", "<leader>ow", "<cmd>OverseerToggle<cr>", { desc = "Task list" })
vim.keymap.set("n", "<leader>or", "<cmd>OverseerRun<cr>", { desc = "Run task" })

vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics (Trouble)" })
vim.keymap.set("n", "<leader>xX", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Buffer Diagnostics (Trouble)" })
vim.keymap.set("n", "<leader>cs", "<cmd>Trouble symbols toggle<cr>", { desc = "Symbols (Trouble)" })
vim.keymap.set(
	"n",
	"<leader>cl",
	"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
	{ desc = "LSP Definitions / references / ... (Trouble)" }
)
vim.keymap.set("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>", { desc = "Location List (Trouble)" })
vim.keymap.set("n", "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix List (Trouble)" })

vim.api.nvim_create_autocmd("PackChanged", {
	callback = function(ev)
		local name, kind = ev.data.spec.name, ev.data.kind
		if name == "blink.cmp" and (kind == "install" or kind == "update") then
			if not ev.data.active then
				vim.cmd.packadd(name)
			end
			require("blink.cmp.fuzzy.build").build()
		end
	end,
})

vim.pack.add({
	{ src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
	"https://github.com/ibhagwan/fzf-lua",
	"https://github.com/MeanderingProgrammer/render-markdown.nvim",
	"https://github.com/techwizrd/render-latex.nvim",
	"https://github.com/nvim-treesitter/nvim-treesitter",
	"https://github.com/folke/which-key.nvim",
	"https://github.com/saghen/blink.cmp",
})

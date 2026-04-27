vim.pack.add({ "https://github.com/rachartier/tiny-cmdline.nvim" })
vim.api.nvim_set_hl(0, "TinyCmdlineBorder", { fg = "#95959e" })
-- vim.api.nvim_set_hl(0, "TinyCmdlineNormal", { bg = "#4c4c6b" })
-- vim.api.nvim_set_hl(0, "TinyCmdlineNormal", { bg = "#d5d5e3" })

require("tiny-cmdline").setup({
	on_reposition = require("tiny-cmdline").adapters.blink,
	width = { value = "40%" },
	position = {
		x = "50%", -- horizontal: "0%" = left, "50%" = center, "100%" = right
		y = "12%", -- vertical:   "0%" = top,  "50%" = center, "100%" = bottom
	},
})

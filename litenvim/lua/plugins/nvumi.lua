vim.pack.add({ "https://github.com/josephburgess/nvumi" })

require("nvumi").setup({
	-- The default is to use the "V" key, but you can change it to whatever you like.
	-- You can also use a table of keys, such as { "V", "gV" }, to use multiple keys.
	virtual_text = "newline", -- or "inline"
	prefix = " = ", -- prefix shown before the output
	date_format = "iso", -- or: "uk", "us", "long"
	width = 0.4, -- 0–1 = fraction of terminal width, >1 = absolute columns
	height = 0.4, -- 0–1 = fraction of terminal height, >1 = absolute lines
	keys = {
		run = "<CR>", -- run/refresh calculations
		reset = "R", -- reset buffer
		yank = "<leader>y", -- yank output of current line
		yank_all = "<leader>Y", -- yank all outputs
	},
	-- see below for more on custom conversions/functions
	custom_conversions = {},
	custom_functions = {},
})

local runner = require("nvumi.runner")
local orig = runner.run_numi
runner.run_numi = function(expr, callback)
	orig(expr, function(data)
		callback(vim.tbl_map(function(s) return s:gsub("\r", "") end, data))
	end)
end

vim.keymap.set("n", "<leader>oc", "<CMD>Nvumi<CR>", { desc = "Open nvumi" })vim.keymap.set("n", "<leader>on", "<CMD>Nvumi<CR>", { desc = "Open nvumi" })

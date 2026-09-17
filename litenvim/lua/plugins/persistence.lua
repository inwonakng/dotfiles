-- Only persist sessions started without file arguments.
if vim.fn.argc() > 0 then
	return
end

vim.pack.add({ "https://github.com/folke/persistence.nvim" })
local persistence = require("persistence")
persistence.setup()

vim.fn.timer_start(5 * 60 * 1000, function()
	if persistence.active() then
		persistence.save()
	end
end, { ["repeat"] = -1 })

vim.keymap.set("n", "<leader>qs", function()
	persistence.load()
end)

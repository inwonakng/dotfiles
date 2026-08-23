-- Only persist sessions started without file arguments.
if vim.fn.argc() > 0 then
	return
end

vim.pack.add({ "https://github.com/folke/persistence.nvim" })
require("persistence").setup()

vim.keymap.set("n", "<leader>qs", function()
	require("persistence").load()
end)

-- stop persistence for temp sessions
if vim.env.IS_TEMP_SESSION == "1" then
	return
end

-- vim.api.nvim_create_autocmd("BufReadPre", {
-- 	once = true,
-- 	callback = function()
-- 		-- single line plugins just live here.
vim.pack.add({ "https://github.com/folke/persistence.nvim" })
require("persistence").setup()
-- 	end,
-- })

vim.keymap.set("n", "<leader>qs", function()
	require("persistence").load()
end)

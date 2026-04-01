-- stop persistence for temp sessions
if vim.env.IS_TEMP_SESSION == "1" then
	return
end

-- stop persistence if opening a claude-code CLI scratch file
if vim.fn.argc() > 0 and tostring(vim.fn.argv(0)):match("claude%-prompt") then
	return
end

vim.pack.add({ "https://github.com/folke/persistence.nvim" })
require("persistence").setup()

vim.keymap.set("n", "<leader>qs", function()
	require("persistence").load()
end)

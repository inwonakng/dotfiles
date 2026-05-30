-- stop persistence for temp sessions
if vim.env.IS_TEMP_SESSION == "1" then
	return
end

local argv0 = vim.fn.argc() > 0 and tostring(vim.fn.argv(0)) or ""

-- stop persistence if opening a CLI scratch file
if argv0:match("claude%-prompt") or argv0:match("^/private/var/folders/.*/T/%.tmp.*%.md$") then
	return
end

vim.pack.add({ "https://github.com/folke/persistence.nvim" })
require("persistence").setup()

vim.keymap.set("n", "<leader>qs", function()
	require("persistence").load()
end)

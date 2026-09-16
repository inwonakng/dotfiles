-- this is the way I set node path in bashrc, so if this is null, assume that
-- we don't have node.
if vim.env.NODE_DEFAULT_PATH == nil then
	return
end

vim.pack.add({ "https://github.com/zbirenbaum/copilot.lua" })

require("copilot").setup({
	suggestion = {
		enabled = true,
		auto_trigger = true,
		keymap = { accept = "<C-a>" },
	},
	panel = {
		enabled = false,
	},
	filetypes = {
		markdown = true,
		help = true,
	},
})

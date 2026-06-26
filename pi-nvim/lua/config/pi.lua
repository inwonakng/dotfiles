local uv = vim.uv or vim.loop
local config_root = uv.fs_realpath(vim.fn.stdpath("config")) or vim.fn.stdpath("config")
local dotfiles_root = vim.fn.fnamemodify(config_root, ":h")

require("pi-integration").setup({
	binary = vim.env.PI_BINARY or "pi",
	agent_dir = vim.env.PI_CODING_AGENT_DIR or (dotfiles_root .. "/pi/agent"),
	provider = vim.env.PI_PROVIDER,
	model = vim.env.PI_MODEL,
	session_dir = vim.env.PI_SESSION_DIR,
	show_thinking = true,
})

vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		require("pi-integration").open()
	end,
})

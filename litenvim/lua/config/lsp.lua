vim.diagnostic.config({
	underline = false,
	signs = true,
	virtual_text = false,
	float = {
		show_header = true,
		source = "always",
		border = "rounded",
		focusable = true,
	},
	update_in_insert = false, -- default to false
	severity_sort = false, -- default to false
})

vim.lsp.config("*", {
	require("blink.cmp").get_lsp_capabilities(),
})

-- vim.lsp.enable({ "ty", "lua_ls", "harper_ls", "taplo", "copilot" })
vim.lsp.enable({ "ty", "lua_ls", "harper_ls", "taplo" })

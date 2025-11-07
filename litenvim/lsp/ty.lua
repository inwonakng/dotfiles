return {
	cmd = { "ty", "server" },
	filetypes = { "python" },
	root_markers = {
		"pyproject.toml",
		"setup.py",
		"setup.cfg",
		"requirements.txt",
		"Pipfile",
		".git",
	},
	-- on_attach = function(client, bufnr)
	-- 	-- Disable hover and signature help since we'll use jedi for these
	-- 	client.server_capabilities.hoverProvider = false
	-- 	client.server_capabilities.signatureHelpProvider = false
	-- end,
}

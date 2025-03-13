return {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
	settings = {
		Lua = {
			format = { enable = true, defaultConfig = { indent_style = "space", indent_size = "4" } },
			workspace = {
				checkThirdParty = false,
			},
			codeLens = {
				enable = true,
			},
			completion = {
				callSnippet = "Replace",
			},
			doc = {
				privateName = { "^_" },
			},
			hint = {
				enable = true,
				setType = false,
				paramType = true,
				paramName = "Disable",
				semicolon = "Disable",
				arrayIndex = "Disable",
			},
		},
	},
}

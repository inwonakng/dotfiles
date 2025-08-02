return {
	-- cmd = { 'jedi-language-server' },
	-- filetypes = { 'python' },
	-- root_markers = {
	--   'pyproject.toml',
	--   'setup.py',
	--   'setup.cfg',
	--   'requirements.txt',
	--   'Pipfile',
	--   '.git',
	-- },
	cmd = { "basedpyright-langserver", "--stdio" },
	filetypes = { "python" },
	root_markers = {
		"pyproject.toml",
		"setup.py",
		"setup.cfg",
		"requirements.txt",
		"Pipfile",
		".git",
	},
	single_file_support = true,
	settings = {
		basedpyright = {
			analysis = {
				autoSearchPaths = true,
				useLibraryCodeForTypes = true,
				diagnosticMode = "openFilesOnly",
				logLevel = "Error",
				typeCheckingMode = "basic",
			},
		},
	},
}

return {
	cmd = { "pylsp" },
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
		pylsp = {
			plugins = {
				jedi = {
					-- auto_import_modules = true,
				},
				pycodestyle = { enabled = false },
			},
		},
	},
}

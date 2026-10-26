local M = {}

function M.workspaces()
	local roots = {
		vim.fs.joinpath(vim.env.HOME, "Library/Mobile Documents/iCloud~md~obsidian/Documents"),
		"/mnt/c/Users/inwon/iCloudDrive/iCloud~md~obsidian",
	}
	local workspaces = {}
	for _, name in ipairs({ "personal", "work" }) do
		for _, root in ipairs(roots) do
			local path = vim.fs.joinpath(root, name)
			if vim.fn.isdirectory(path) == 1 then
				table.insert(workspaces, { name = name, path = path })
				break
			end
		end
	end
	return workspaces
end

function M.cli()
	-- Use the terminal redirector, never the Windows GUI executable: timed
	-- requests must not kill the app or lose its stdout.
	local candidates
	if vim.fn.has("wsl") == 1 then
		candidates = {
			"Obsidian.com",
			"/mnt/c/Users/inwon/AppData/Local/Programs/Obsidian/Obsidian.com",
			"/mnt/c/Users/inwon/AppData/Local/Obsidian/Obsidian.com",
			"/mnt/c/Program Files/Obsidian/Obsidian.com",
		}
	else
		candidates = { "/Applications/Obsidian.app/Contents/MacOS/obsidian-cli", "obsidian-cli", "obsidian" }
	end
	for _, candidate in ipairs(candidates) do
		if vim.fn.executable(candidate) == 1 then
			return candidate
		end
	end
	error("Enable the Obsidian CLI in Settings > General (Obsidian.com must be available on Windows)")
end

function M.open(uri)
	if vim.fn.has("wsl") == 1 then
		-- PowerShell handles the URI through Windows without cmd.exe interpreting
		-- its ampersands. Quote it as a literal PowerShell string.
		return vim.system({
			"powershell.exe",
			"-NoProfile",
			"-NonInteractive",
			"-Command",
			"Start-Process -FilePath '" .. uri:gsub("'", "''") .. "'",
		}, { text = true })
	end
	return vim.ui.open(uri)
end

function M.launch(workspace)
	local process, err
	if vim.fn.has("mac") == 1 then
		process = vim.system({ "open", "-g", "-a", "Obsidian" }, { text = true })
	else
		process, err = M.open("obsidian://open?vault=" .. vim.uri_encode(workspace.name))
	end
	if not process then
		error("Could not launch Obsidian: " .. tostring(err))
	end
	local result = process:wait(10000)
	if result.code ~= 0 then
		error("Could not launch Obsidian: " .. vim.trim(result.stderr or ""))
	end
end

return M

local M = {}
local uv = vim.uv
local cli = "/Applications/Obsidian.app/Contents/MacOS/obsidian-cli"

local function find_target(kind, workspaces)
	local directory = vim.fn.getcwd()
	local marker = "." .. kind
	while directory do
		local candidate = vim.fs.joinpath(directory, marker)
		if uv.fs_lstat(candidate) then
			local target = uv.fs_realpath(candidate)
			if not target or vim.fn.isdirectory(target) ~= 1 then
				error("Broken or invalid project note directory: " .. candidate)
			end
			for _, workspace in ipairs(workspaces) do
				local root = uv.fs_realpath(workspace.path)
				if root and target:sub(1, #root + 1) == root .. "/" then
					local relative = target:sub(#root + 2)
					if not relative:match("^projects/[^/]+/" .. kind .. "$") then
						error(marker .. " must target projects/<project>/" .. kind .. " in a configured vault")
					end
					return workspace, target, relative
				end
			end
			error(marker .. " is outside the configured Obsidian vaults")
		end
		local parent = vim.fs.dirname(directory)
		if parent == directory then
			break
		end
		directory = parent
	end
	error("No " .. marker .. " directory found in the current directory or its parents")
end

local function evaluate(workspace, code)
	local result = vim.system({ cli, "vault=" .. workspace.name, "eval", "code=" .. code }, { text = true }):wait(10000)
	local output = vim.trim(result.stdout or "")
	if result.code ~= 0 then
		error("Obsidian CLI failed: " .. vim.trim((result.stderr or "") .. "\n" .. output))
	end
	local ok, value = pcall(vim.json.decode, (output:gsub("^=>%s*", "")))
	if not ok or type(value) ~= "table" then
		error("Unexpected Obsidian CLI response: " .. output)
	end
	return value
end

local function open_buffer(path)
	local buffer = vim.fn.bufnr(path)
	local windows = buffer ~= -1 and vim.fn.win_findbuf(buffer) or {}
	if windows[1] then
		vim.api.nvim_set_current_win(windows[1])
	else
		vim.cmd.edit(vim.fn.fnameescape(path))
	end
end

function M.open(kind, workspaces)
	local ok, err = pcall(function()
		local workspace, target, relative = find_target(kind, workspaces)
		local path = vim.fs.joinpath(target, os.date("%Y-%m-%d") .. ".md")
		if vim.fn.filereadable(path) == 1 then
			open_buffer(path)
			return
		end
		if vim.fn.executable(cli) ~= 1 then
			error("Enable the Obsidian CLI to create project notes")
		end
		local launched = vim.system({ "open", "-g", "-a", "Obsidian" }, { text = true }):wait(10000)
		if launched.code ~= 0 then
			error("Could not launch Obsidian: " .. vim.trim(launched.stderr or ""))
		end
		local last_error
		if not vim.wait(30000, function()
			local ready, response = pcall(
				evaluate,
				workspace,
				'JSON.stringify({ready:typeof app.plugins.plugins["templater-obsidian"]?.projectNotes?.open==="function"})'
			)
			last_error = ready and "Enable Templater startup templates and reload Templater in this vault" or response
			return ready and response.ready == true
		end, 250) then
			error("Project-note commands unavailable: " .. tostring(last_error))
		end
		local response = evaluate(
			workspace,
			('(async()=>JSON.stringify({path:await app.plugins.plugins["templater-obsidian"].projectNotes.open(%s,%s,false)}))()'):format(
				vim.json.encode(kind),
				vim.json.encode(relative)
			)
		)
		if type(response.path) ~= "string" or not response.path:match("^" .. vim.pesc(relative) .. "/%d%d%d%d%-%d%d%-%d%d%.md$") then
			error("Obsidian returned an invalid project note path")
		end
		path = vim.fs.joinpath(workspace.path, response.path)
		if vim.fn.filereadable(path) ~= 1 then
			error("Project note was not created: " .. path)
		end
		open_buffer(path)
	end)
	if not ok then
		vim.notify(tostring(err), vim.log.levels.ERROR)
	end
end

local function skip_initialized(project)
	for _, kind in ipairs({ "todo", "notes" }) do
		local path = vim.fs.joinpath(project, "." .. kind)
		if uv.fs_lstat(path) then
			vim.notify("Skipping initialization: " .. path .. " already exists")
			return true
		end
	end
	return false
end

local function ensure_directory(path)
	local stat = uv.fs_lstat(path)
	if stat then
		if stat.type ~= "directory" then
			error("Expected a real directory: " .. path)
		end
		return
	end
	local ok, err = uv.fs_mkdir(path, 493) -- 0755, respecting the process umask.
	if not ok then
		error("Could not create directory " .. path .. ": " .. tostring(err))
	end
end

function M.initialize(workspaces)
	local project = vim.fn.getcwd()
	if skip_initialized(project) then
		return
	end
	if #workspaces == 0 then
		vim.notify("No Obsidian vaults are configured", vim.log.levels.ERROR)
		return
	end
	-- fzf-lua is registered as the vim.ui.select provider in plugins/fzf.lua.
	vim.ui.select(workspaces, {
		prompt = "Project notes vault",
		format_item = function(workspace)
			return workspace.name
		end,
	}, function(workspace)
		if not workspace then
			return
		end
		vim.ui.input({ prompt = "Project name: ", default = vim.fs.basename(project) }, function(name)
			if name == nil then
				return
			end
			name = vim.trim(name)
			if name == "" or name == "." or name == ".." or name:find("[/\\%z\1-\31]") then
				vim.notify("Project name must be a single non-empty directory name", vim.log.levels.ERROR)
				return
			end
			if skip_initialized(project) then
				return
			end
			local created_links = {}
			local ok, err = pcall(function()
				local root = uv.fs_realpath(workspace.path)
				if not root or vim.fn.isdirectory(root) ~= 1 then
					error("Vault directory is unavailable: " .. workspace.path)
				end
				local projects = vim.fs.joinpath(root, "projects")
				local target = vim.fs.joinpath(projects, name)
				ensure_directory(projects)
				ensure_directory(target)
				for _, kind in ipairs({ "todo", "notes" }) do
					ensure_directory(vim.fs.joinpath(target, kind))
				end
				for _, kind in ipairs({ "todo", "notes" }) do
					local destination = vim.fs.joinpath(project, "." .. kind)
					local source = vim.fs.joinpath(target, kind)
					local linked, link_error = uv.fs_symlink(source, destination)
					if not linked then
						error("Could not link " .. destination .. ": " .. tostring(link_error))
					end
					table.insert(created_links, { source = source, destination = destination })
				end
				vim.notify("Project notes linked to " .. target)
			end)
			if not ok then
				-- Roll back only our links, never existing vault directories or notes.
				for _, link in ipairs(created_links) do
					if uv.fs_readlink(link.destination) == link.source then
						local removed, remove_error = uv.fs_unlink(link.destination)
						if not removed then
							vim.notify("Could not remove partial link: " .. tostring(remove_error), vim.log.levels.ERROR)
						end
					end
				end
				vim.notify(tostring(err), vim.log.levels.ERROR)
			end
		end)
	end)
end

return M

-- Session UI depends on this module, not on a particular multiplexer.
-- Backends implement available/list/focus/launch/publish/clear/start_overview.
-- start_overview registers the overview's location for backend navigation.
-- list() returns snapshots plus an opaque instance id and a readable location.
-- Operations return a non-nil value on success, or nil and an error message.
local M = {}
local timer
local publisher_state

local function backend()
	local tmux = require("pi-integration.backends.tmux")
	if tmux.available() then
		return tmux
	end
end

function M.available()
	return backend() ~= nil
end

function M.start_overview()
	local transport = backend()
	if transport then
		return transport.start_overview()
	end
	return true
end

function M.canonical_path(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	return vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
end

function M.list()
	local transport = backend()
	if not transport then
		return {}
	end
	return transport.list()
end

function M.find_session(path)
	local instances, err = M.list()
	if not instances then
		return nil, err
	end
	path = M.canonical_path(path)
	for _, entry in ipairs(instances) do
		if path and M.canonical_path(entry.path) == path then
			return entry
		end
	end
end

function M.focus(id)
	local transport = backend()
	if not transport then
		return nil, "No supported session backend is available"
	end
	-- Avoid focusing a shell that has replaced the selected conversation.
	local instances, err = transport.list()
	if not instances then
		return nil, err
	end
	for _, entry in ipairs(instances) do
		if entry.id == id then
			return transport.focus(id)
		end
	end
	return nil, "That conversation is no longer open"
end

function M.launch(launcher, cwd, path)
	local transport = backend()
	if not transport then
		return nil, "No supported session backend is available"
	end
	if path then
		path = M.canonical_path(path)
		if not path then
			return nil, "Invalid session path"
		end
		local existing, err = M.find_session(path)
		if err then
			return nil, err
		end
		if existing then
			return M.focus(existing.id)
		end
		if vim.fn.filereadable(path) ~= 1 then
			return nil, "Session file no longer exists: " .. path
		end
	end
	if vim.fn.isdirectory(cwd) ~= 1 then
		return nil, "Directory no longer exists: " .. cwd
	end
	if vim.fn.filereadable(launcher) ~= 1 then
		return nil, "Launcher no longer exists: " .. launcher
	end
	return transport.launch(launcher, cwd, path)
end

local function snapshot(state)
	local status = "Idle"
	local waiting
	for _, request in pairs(state.pending_ui_requests or {}) do
		if not request.expires or request.expires > vim.uv.now() then
			waiting = request.title
			break
		end
	end
	if not state.job or state.job <= 0 then
		status = "Stopped"
	elseif waiting then
		status = "Waiting"
	elseif state.is_retrying then
		status = "Retrying"
	elseif state.is_compacting then
		status = "Compacting"
	elseif state.is_streaming or state.awaiting_agent_output then
		status = "Working"
	elseif state.error_rendered_for_active_run then
		status = "Error"
	end
	local path = state.session_file or state.pending_session_file
	return {
		version = 1,
		pid = vim.uv.os_getpid(),
		updated = os.time(),
		path = path,
		title = state.session_name or (path and vim.fn.fnamemodify(path, ":t")) or "New conversation",
		cwd = (state.workspace and state.workspace.cwd) or vim.fn.getcwd(),
		directory = (state.workspace and state.workspace.directory) or (state.workspace and state.workspace.cwd) or vim.fn.getcwd(),
		workspace_id = state.workspace and state.workspace.id,
		status = status,
		activity = waiting or state.activity_label or "",
		model = state.model_id,
		subagents = state.spawn_running_count or 0,
	}
end

function M.publish()
	local transport = backend()
	if publisher_state and transport then
		return transport.publish(snapshot(publisher_state))
	end
end

function M.stop()
	if timer then
		timer:stop()
		timer:close()
		timer = nil
	end
	publisher_state = nil
	local transport = backend()
	if transport then
		transport.clear()
	end
end

function M.start(state)
	if timer or not M.available() then
		return
	end
	publisher_state = state
	M.publish()
	timer = vim.uv.new_timer()
	timer:start(
		1000,
		1000,
		vim.schedule_wrap(function()
			if timer then
				M.publish()
			end
		end)
	)
	vim.api.nvim_create_autocmd("VimLeavePre", { once = true, callback = M.stop })
end

return M

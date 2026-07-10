local M = {}

local function is_local_host(host)
	return not host or host == "" or host == "localhost" or host == "127.0.0.1"
end

local function ssh_hosts_from_config()
	local path = vim.fn.expand("~/.ssh/config")
	if vim.fn.filereadable(path) ~= 1 then
		return {}
	end
	local hosts = {}
	local seen = {}
	for _, line in ipairs(vim.fn.readfile(path)) do
		local value = line:match("^%s*[Hh][Oo][Ss][Tt]%s+(.+)%s*$")
		if value then
			for host in value:gmatch("%S+") do
				if not host:find("*", 1, true) and not host:find("?", 1, true) and not seen[host] then
					seen[host] = true
					table.insert(hosts, host)
				end
			end
		end
	end
	table.sort(hosts)
	return hosts
end

local function pick_host(callback)
	local choices = { "localhost" }
	vim.list_extend(choices, ssh_hosts_from_config())
	vim.ui.select(choices, { prompt = "Pi host" }, callback)
end

local function request(ctx, host, cmd, callback)
	ctx.rpc.manager_request(cmd, callback, host)
end

local function format_time(ms_or_s)
	local n = tonumber(ms_or_s) or 0
	if n > 20000000000 then
		n = math.floor(n / 1000)
	end
	if n <= 0 then
		return "unknown"
	end
	return os.date("%Y-%m-%d %H:%M", n)
end

local function basename(path)
	if not path or path == "" then
		return ""
	end
	return vim.fn.fnamemodify(path, ":t")
end

local function run_label(run)
	local attached = run.attached and (run.stale and "attached stale" or "attached") or "free"
	local title = run.sessionName or basename(run.sessionFile) or "new session"
	return string.format("run · %s · %s · %s · %s", run.status or "unknown", attached, title, run.cwd or "")
end

local function session_label(session)
	local title = session.title or basename(session.path)
	return string.format("session · %s · %s · %s", title, session.cwd or "cwd unknown", format_time(session.mtime))
end

local function close_float(win, buf)
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
	if buf and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_delete(buf, { force = true })
	end
end

function M.explore_cwd(ctx, host, start_path, callback)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", "pi-cwd-picker", { buf = buf })

	local width = math.min(math.max(72, math.floor(vim.o.columns * 0.75)), vim.o.columns - 4)
	local height = math.min(math.max(16, math.floor(vim.o.lines * 0.65)), vim.o.lines - 4)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.max(1, math.floor((vim.o.lines - height) / 2)),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		style = "minimal",
		border = "rounded",
		title = " Pi cwd: " .. host .. " ",
		title_pos = "left",
	})

	local state = {
		path = start_path or (is_local_host(host) and vim.fn.getcwd() or "~"),
		dirs = {},
		home = nil,
		parent = nil,
		line_items = {},
	}

	local function set_lines(lines)
		vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	end

	local function load(path)
		set_lines({ "Loading " .. tostring(path) .. " ..." })
		request(ctx, host, { type = "manager_list_dir", path = path }, function(event)
			if not (event.success and event.data) then
				set_lines({ "Error: " .. tostring(event.error or "could not list directory") })
				return
			end
			state.path = event.data.path
			state.parent = event.data.parent
			state.home = event.data.home
			state.dirs = event.data.dirs or {}
			state.line_items = {}
			local lines = {
				"Host: " .. host,
				"Current: " .. state.path,
				"",
				"[Use this directory]",
			}
			table.insert(state.line_items, false)
			table.insert(state.line_items, false)
			table.insert(state.line_items, false)
			table.insert(state.line_items, { kind = "use" })
			for _, dir in ipairs(state.dirs) do
				table.insert(lines, dir.name .. "/")
				table.insert(state.line_items, { kind = "dir", path = dir.path })
			end
			set_lines(lines)
			vim.api.nvim_win_set_cursor(win, { 4, 0 })
		end)
	end

	local function select_current()
		close_float(win, buf)
		callback(state.path)
	end

	local function cancel()
		close_float(win, buf)
		callback(nil)
	end

	vim.keymap.set("n", "<CR>", function()
		local line = vim.api.nvim_win_get_cursor(win)[1]
		local item = state.line_items[line]
		if not item then
			return
		end
		if item.kind == "use" then
			select_current()
		elseif item.kind == "dir" then
			load(item.path)
		end
	end, { buffer = buf, silent = true })
	vim.keymap.set("n", "-", function()
		load(state.parent or state.path)
	end, { buffer = buf, silent = true })
	vim.keymap.set("n", "~", function()
		load(state.home or "~")
	end, { buffer = buf, silent = true })
	vim.keymap.set("n", "i", function()
		vim.ui.input({ prompt = "Cwd", default = state.path }, function(value)
			if value and value ~= "" then
				load(value)
			end
		end)
	end, { buffer = buf, silent = true })
	vim.keymap.set("n", "q", cancel, { buffer = buf, silent = true })
	vim.keymap.set("n", "<Esc>", cancel, { buffer = buf, silent = true })

	load(state.path)
end

local function detach_then(ctx, fn)
	ctx.rpc.detach(function()
		fn()
	end)
end

function M.new_session_on_host(ctx, host)
	M.explore_cwd(ctx, host, is_local_host(host) and vim.fn.getcwd() or "~", function(cwd)
		if not cwd then
			return
		end
		ctx.rpc.spawn_and_attach(host, { cwd = cwd }, function(event)
			if event and event.success then
				ctx.ui.notify("Started Pi in " .. cwd)
			end
		end)
	end)
end

function M.new_session(ctx)
	detach_then(ctx, function()
		pick_host(function(host)
			if host then
				M.new_session_on_host(ctx, host)
			end
		end)
	end)
end

local function attach_session(ctx, host, session)
	local function spawn(cwd)
		if not cwd then
			return
		end
		ctx.rpc.spawn_and_attach(host, { cwd = cwd, sessionPath = session.path }, function(event)
			if event and event.success then
				ctx.ui.notify("Attached session " .. tostring(session.title or session.path))
			end
		end)
	end
	if session.cwd and session.cwd ~= "" then
		spawn(session.cwd)
	else
		M.explore_cwd(ctx, host, is_local_host(host) and vim.fn.getcwd() or "~", spawn)
	end
end

function M.pick(ctx)
	detach_then(ctx, function()
		pick_host(function(host)
			if not host then
				return
			end
			request(ctx, host, { type = "manager_list_runs" }, function(runs_event)
				if not runs_event.success then
					ctx.ui.notify(runs_event.error or "Could not list Pi runs", vim.log.levels.ERROR)
					return
				end
				request(ctx, host, { type = "manager_list_sessions" }, function(sessions_event)
					if not sessions_event.success then
						ctx.ui.notify(sessions_event.error or "Could not list Pi sessions", vim.log.levels.ERROR)
						return
					end
					local choices = {
						{ kind = "new", label = "New session..." },
					}
					for _, run in ipairs((runs_event.data and runs_event.data.runs) or {}) do
						table.insert(choices, { kind = "run", run = run, label = run_label(run) })
					end
					for _, session in ipairs((sessions_event.data and sessions_event.data.sessions) or {}) do
						table.insert(choices, { kind = "session", session = session, label = session_label(session) })
					end
					vim.ui.select(choices, {
						prompt = "Pi target on " .. host,
						format_item = function(item)
							return item.label
						end,
					}, function(choice)
						if not choice then
							return
						end
						if choice.kind == "new" then
							M.new_session_on_host(ctx, host)
						elseif choice.kind == "run" then
							if choice.run.attached and not choice.run.stale then
								ctx.ui.notify("That Pi run is already attached", vim.log.levels.WARN)
								return
							end
							ctx.rpc.attach_run(host, choice.run.runId)
						elseif choice.kind == "session" then
							attach_session(ctx, host, choice.session)
						end
					end)
				end)
			end)
		end)
	end)
end

function M.detach(ctx)
	ctx.rpc.detach(function(event)
		if event.success then
			ctx.ui.notify("Detached Pi run")
		else
			ctx.ui.notify(event.error or "Could not detach Pi run", vim.log.levels.ERROR)
		end
	end)
end

function M.kill(ctx)
	ctx.rpc.kill(function(event)
		if event.success then
			ctx.ui.notify("Killed Pi run")
		else
			ctx.ui.notify(event.error or "Could not kill Pi run", vim.log.levels.ERROR)
		end
	end)
end

function M.complete_files(ctx, cwd, prefix, callback)
	local host = ctx.state.target_host or ctx.state.manager_host or "localhost"
	request(ctx, host, { type = "manager_complete_files", cwd = cwd, prefix = prefix or "" }, function(event)
		if event.success and event.data then
			callback(event.data.files or {})
		else
			callback(nil, event.error or "completion failed")
		end
	end)
end

return M

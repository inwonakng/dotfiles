local json = require("pi-integration.utils.json")

local M = {}

local function is_local_host(host)
	return not host or host == "" or host == "localhost" or host == "127.0.0.1"
end

local function is_manager_command(cmd)
	return type(cmd) == "table" and type(cmd.type) == "string" and cmd.type:match("^manager_") ~= nil
end

local function decode_json(ctx, line)
	local decoded = json.decode(line)
	if decoded ~= nil then
		return decoded
	end
	ctx.transcript.render_error_message("Pi Error", "Bad JSON from pi manager: " .. line)
	return nil
end

local function next_request_id(state)
	state.next_id = state.next_id + 1
	return "pi-nvim-" .. tostring(state.next_id)
end

function M.handle_response(ctx, event)
	local state = ctx.state
	local callback = event.id and state.callbacks[event.id]
	if callback then
		state.callbacks[event.id] = nil
		callback(event)
		return
	end

	if event.success == false then
		ctx.transcript.render_error_message("Pi Error", ctx.rpc.event_error_text(event) or vim.inspect(event))
	end
end

function M.handle_jsonl_data(ctx, data, pending_key)
	local state = ctx.state
	if not data then
		return
	end

	for i, chunk in ipairs(data) do
		if i == 1 then
			chunk = state[pending_key] .. chunk
		end

		if i < #data then
			chunk = chunk:gsub("\r$", "")
			if chunk ~= "" then
				local event = decode_json(ctx, chunk)
				if event then
					ctx.rpc.handle_event(event)
				end
			end
			state[pending_key] = ""
		else
			state[pending_key] = chunk
		end
	end
end

function M.argv(ctx)
	local state = ctx.state
	local config = ctx.config
	local host = state.manager_host or "localhost"
	if is_local_host(host) then
		return { config.manager_binary, "--stdio" }
	end
	return { config.ssh_binary or "ssh", host, (config.remote_manager_binary or "pi-nvim-manager") .. " --stdio" }
end

function M.job_env(_ctx)
	return nil
end

local function close_heartbeat(state)
	if state.heartbeat_timer then
		state.heartbeat_timer:stop()
		state.heartbeat_timer:close()
		state.heartbeat_timer = nil
	end
end

function M.start(ctx, host)
	local state = ctx.state
	if host and host ~= "" and host ~= state.manager_host then
		M.stop(ctx)
		state.manager_host = host
	end
	if state.job and state.job > 0 then
		return
	end
	state.last_stderr_lines = {}
	state.error_rendered_for_active_run = false
	state.is_retrying = false
	state.pending_retry_error = nil
	state.stdout_pending = ""
	state.stderr_pending = ""

	state.job = vim.fn.jobstart(M.argv(ctx), {
		stdin = "pipe",
		env = M.job_env(ctx),
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = function(_, data, _)
			vim.schedule(function()
				M.handle_jsonl_data(ctx, data, "stdout_pending")
			end)
		end,
		on_stderr = function(_, data, _)
			vim.schedule(function()
				for _, line in ipairs(data or {}) do
					if line ~= "" then
						table.insert(state.last_stderr_lines, line)
						if #state.last_stderr_lines > 20 then
							table.remove(state.last_stderr_lines, 1)
						end
					end
					if ctx.config.show_stderr and line ~= "" then
						ctx.transcript.append_status("pi manager stderr: " .. line)
					end
				end
			end)
		end,
		on_exit = function(_, code, _)
			vim.schedule(function()
				state.job = nil
				state.manager_connected = false
				state.target_attached = false
				state.is_streaming = false
				state.is_retrying = false
				state.awaiting_agent_output = false
				state.pending_retry_error = nil
				if state.activity_timer then
					state.activity_timer:stop()
					state.activity_timer:close()
					state.activity_timer = nil
				end
				state.activity_label = nil
				state.activity_tool_call_id = nil
				state.activity_spinner_tick = 1
				close_heartbeat(state)
				if ctx.transcript.assistant_placeholder_active() and not state.error_rendered_for_active_run then
					ctx.transcript.render_error_message(
						"Pi Error",
						ctx.rpc.recent_stderr_text() or ("pi manager exited with code " .. tostring(code))
					)
				end
				ctx.transcript.refresh_ui()
			end)
		end,
	})

	if state.job <= 0 then
		ctx.ui.notify("Failed to start pi-nvim-manager", vim.log.levels.ERROR)
		state.job = nil
		return
	end
	state.manager_connected = true
end

local function raw_send(ctx, cmd, callback)
	local state = ctx.state
	M.start(ctx)
	if not state.job or state.job <= 0 then
		ctx.transcript.render_error_message("Pi Error", "Could not start pi-nvim-manager.")
		return false
	end

	if callback then
		cmd.id = cmd.id or next_request_id(state)
		state.callbacks[cmd.id] = callback
	end

	local line = json.encode(cmd) .. "\n"
	local sent = vim.fn.chansend(state.job, line)
	if sent == 0 then
		if cmd.id then
			state.callbacks[cmd.id] = nil
		end
		ctx.transcript.render_error_message("Pi Error", "Could not send request to pi manager; the channel is closed.")
		return false
	end
	return true
end

local function refresh_after_attach(ctx)
	raw_send(ctx, { type = "get_state" }, function(event)
		if event.success and event.data then
			ctx.session.apply_state(event.data)
			ctx.actions.refresh_session_stats()
			if not ctx.state.is_streaming then
				ctx.actions.refresh_messages()
			end
		end
	end)
end

local function start_heartbeat(ctx)
	local state = ctx.state
	close_heartbeat(state)
	if not state.target_run_id then
		return
	end
	local timer = vim.uv.new_timer()
	state.heartbeat_timer = timer
	timer:start(10000, 10000, vim.schedule_wrap(function()
		if state.job and state.job > 0 and state.target_attached and state.target_run_id then
			raw_send(ctx, {
				type = "manager_heartbeat",
				runId = state.target_run_id,
				clientId = state.manager_client_id,
			})
		end
	end))
end

function M.attach_run(ctx, host, run_id, callback)
	local state = ctx.state
	if not run_id or run_id == "" then
		ctx.ui.notify("No Pi run id selected", vim.log.levels.ERROR)
		return
	end
	M.start(ctx, host or state.manager_host or "localhost")
	raw_send(ctx, {
		type = "manager_attach",
		runId = run_id,
		clientId = state.manager_client_id,
	}, function(event)
		if event.success and event.data and event.data.run then
			local run = event.data.run
			state.target_run_id = run.runId
			state.target_host = state.manager_host
			state.target_cwd = run.cwd
			state.target_attached = true
			state.pending_session_file = run.sessionFile
			state.session_file = run.sessionFile
			start_heartbeat(ctx)
			refresh_after_attach(ctx)
			ctx.ui.notify("Attached Pi run " .. tostring(run.runId))
		else
			ctx.ui.notify(event.error or "Could not attach Pi run", vim.log.levels.ERROR)
		end
		if callback then
			callback(event)
		end
	end)
end

function M.spawn_and_attach(ctx, host, opts, callback)
	local state = ctx.state
	opts = opts or {}
	M.start(ctx, host or state.manager_host or "localhost")
	raw_send(ctx, {
		type = "manager_spawn",
		cwd = opts.cwd or vim.fn.getcwd(),
		sessionPath = opts.sessionPath,
		agentDir = ctx.config.agent_dir,
		provider = ctx.config.provider,
		model = ctx.config.model,
		sessionDir = ctx.config.session_dir,
		binary = ctx.config.binary,
	}, function(event)
		if event.success and event.data and event.data.run then
			M.attach_run(ctx, state.manager_host, event.data.run.runId, callback)
		else
			ctx.ui.notify(event.error or "Could not spawn Pi run", vim.log.levels.ERROR)
			if callback then
				callback(event)
			end
		end
	end)
end

function M.ensure_default_attached(ctx, callback)
	local state = ctx.state
	if state.target_attached and state.target_run_id then
		callback(true)
		return
	end
	M.spawn_and_attach(ctx, "localhost", { cwd = vim.fn.getcwd() }, function(event)
		callback(event and event.success == true)
	end)
end

function M.send(ctx, cmd, callback)
	if is_manager_command(cmd) then
		return raw_send(ctx, cmd, callback)
	end
	if ctx.state.target_attached and ctx.state.target_run_id then
		return raw_send(ctx, cmd, callback)
	end
	M.ensure_default_attached(ctx, function(ok)
		if ok then
			raw_send(ctx, cmd, callback)
		else
			ctx.transcript.render_error_message("Pi Error", "Could not attach a Pi run for this request.")
		end
	end)
end

function M.manager_request(ctx, cmd, callback, host)
	if host then
		M.start(ctx, host)
	else
		M.start(ctx)
	end
	return raw_send(ctx, cmd, callback)
end

function M.detach(ctx, callback)
	local state = ctx.state
	if not (state.job and state.job > 0) or not state.target_attached then
		if callback then
			callback({ success = true })
		end
		return
	end
	raw_send(ctx, { type = "manager_detach", runId = state.target_run_id }, function(event)
		state.target_attached = false
		state.target_run_id = nil
		close_heartbeat(state)
		if callback then
			callback(event)
		end
	end)
end

function M.kill(ctx, callback)
	local state = ctx.state
	if not (state.job and state.job > 0) then
		if callback then
			callback({ success = false, error = "manager is not running" })
		end
		return
	end
	raw_send(ctx, { type = "manager_kill", runId = state.target_run_id }, function(event)
		state.target_attached = false
		state.target_run_id = nil
		state.is_streaming = false
		close_heartbeat(state)
		if callback then
			callback(event)
		end
	end)
end

function M.stop(ctx)
	local state = ctx.state
	close_heartbeat(state)
	if state.job and state.job > 0 then
		vim.fn.jobstop(state.job)
	end
	state.job = nil
	state.manager_connected = false
	state.target_attached = false
end

return M

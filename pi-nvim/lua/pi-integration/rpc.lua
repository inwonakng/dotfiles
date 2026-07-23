local json = require("pi-integration.utils.json")

local M = {}

local function decode_json(ctx, line)
	local decoded = json.decode(line)
	if decoded ~= nil then
		return decoded
	end
	ctx.logs.add("error", "Bad JSON from pi", line)
	ctx.transcript.render_error_message("Pi Error", "Bad JSON from pi: " .. line)
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
		local message = ctx.rpc.event_error_text(event) or vim.inspect(event)
		ctx.logs.add("error", "Pi RPC response failed", message)
		ctx.transcript.render_error_message("Pi Error", message)
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
	local args = { config.binary, "--mode", "rpc" }
	if state.pending_session_file and state.pending_session_file ~= "" then
		vim.list_extend(args, { "--session", vim.fn.expand(state.pending_session_file) })
	end
	if config.provider and config.provider ~= "" then
		vim.list_extend(args, { "--provider", config.provider })
	end
	if config.model and config.model ~= "" then
		vim.list_extend(args, { "--model", config.model })
	end
	if config.session_dir and config.session_dir ~= "" then
		vim.list_extend(args, { "--session-dir", vim.fn.expand(config.session_dir) })
	end
	return args
end

function M.job_env(ctx)
	if ctx.config.agent_dir and ctx.config.agent_dir ~= "" then
		return { PI_CODING_AGENT_DIR = vim.fn.expand(ctx.config.agent_dir) }
	end
	return nil
end

function M.start(ctx)
	local state = ctx.state
	if state.job and state.job > 0 then
		return
	end
	state.last_stderr_lines = {}
	state.error_rendered_for_active_run = false
	state.is_retrying = false
	state.pending_retry_error = nil

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
						ctx.logs.add("stderr", line)
					end
					if ctx.config.show_stderr and line ~= "" then
						ctx.transcript.append_status("pi stderr: " .. line)
					end
				end
			end)
		end,
		on_exit = function(_, code, _)
			vim.schedule(function()
				if state.session_file and state.session_file ~= "" then
					state.pending_session_file = state.session_file
				end
				local awaiting_output = state.awaiting_agent_output
				ctx.logs.add(code == 0 and "info" or "error", "pi exited with code " .. tostring(code), ctx.rpc.recent_stderr_text())
				if (ctx.transcript.assistant_placeholder_active() or awaiting_output) and not state.error_rendered_for_active_run then
					ctx.transcript.render_error_message(
						"Pi Error",
						ctx.rpc.recent_stderr_text() or ("pi exited with code " .. tostring(code) .. " before returning a message")
					)
				else
					ctx.transcript.append_status("pi exited with code " .. tostring(code))
				end
				state.job = nil
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
				ctx.transcript.refresh_ui()
				state.abort_requested = false
			end)
		end,
	})

	if state.job <= 0 then
		ctx.logs.add("error", "Failed to start pi. Is `pi` on PATH?")
		ctx.ui.notify("Failed to start pi. Is `pi` on PATH?", vim.log.levels.ERROR)
		state.job = nil
		return
	end

	M.send(ctx, { type = "get_state" }, function(event)
		if event.success and event.data then
			state.pending_session_file = nil
			ctx.session.apply_state(event.data)
			ctx.actions.refresh_session_stats()
		end
	end)
	if state.pending_access_mode then
		local mode = state.pending_access_mode
		M.send(ctx, { type = "prompt", message = "/pi-mode " .. mode }, function(event)
			if event.success then
				state.pending_access_mode = nil
			else
				ctx.ui.notify(event.error or "Could not set access mode", vim.log.levels.ERROR)
			end
		end)
	end
end

function M.send(ctx, cmd, callback)
	local state = ctx.state
	M.start(ctx)
	if not state.job or state.job <= 0 then
		ctx.logs.add("error", "Could not start pi. Is `pi` on PATH?")
		ctx.transcript.render_error_message("Pi Error", "Could not start pi. Is `pi` on PATH?")
		return
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
		ctx.logs.add("error", "Could not send request to pi; the RPC channel is closed.", cmd)
		ctx.transcript.render_error_message("Pi Error", "Could not send request to pi; the RPC channel is closed.")
	end
end

function M.stop(ctx)
	local state = ctx.state
	if state.job and state.job > 0 then
		vim.fn.jobstop(state.job)
	end
end

return M

local guard = require("pi-integration.utils.guard")

local M = {}

local function apply_session_cache_footprint(stats, messages)
	if type(stats) ~= "table" or type(stats.tokens) ~= "table" or type(messages) ~= "table" then
		return
	end

	local cache_read = 0
	local cache_write = 0
	for _, message in ipairs(messages) do
		if type(message) == "table" and message.role == "assistant" and type(message.usage) == "table" then
			cache_read = math.max(cache_read, tonumber(message.usage.cacheRead) or 0)
			cache_write = math.max(cache_write, tonumber(message.usage.cacheWrite) or 0)
		end
	end

	stats.tokens.sessionCacheRead = cache_read
	stats.tokens.sessionCacheWrite = cache_write
end

function M.refresh_session_stats(ctx)
	local state = ctx.state
	ctx.rpc.send({ type = "get_session_stats" }, function(event)
		if event.success and event.data then
			state.session_stats = event.data
			ctx.transcript.update_statusline()

			ctx.rpc.send({ type = "get_messages" }, function(messages_event)
				if messages_event.success and messages_event.data then
					apply_session_cache_footprint(state.session_stats, messages_event.data.messages)
					ctx.transcript.update_statusline()
				end
			end)
		end
	end)
end

local function get_input(ctx)
	local state = ctx.state
	if not ctx.buffer.valid(state.input_buf) then
		return ""
	end
	local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)
	return vim.trim(table.concat(lines, "\n"))
end

local function clear_input(ctx)
	local state = ctx.state
	if ctx.buffer.valid(state.input_buf) then
		vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "" })
	end
end

function M.submit_prompt(ctx)
	local state = ctx.state
	local text = get_input(ctx)
	if text == "" then
		return
	end
	if state.is_retrying then
		ctx.ui.notify("Pi is retrying; wait or abort before sending another prompt.", vim.log.levels.WARN)
		return
	end
	state.abort_requested = false
	state.error_rendered_for_active_run = false
	clear_input(ctx)
	ctx.transcript.remove_status(ctx.notices.initial_session)
	ctx.transcript.remove_status(ctx.notices.new_session)
	ctx.transcript.remove_status(ctx.notices.pending_new_session)
	state.pending_user_message = text
	ctx.transcript.touch()
	ctx.transcript.append_message_header("You")
	ctx.transcript.append_text(text)

	local cmd = { type = "prompt", message = text }
	if state.is_streaming then
		cmd.streamingBehavior = "steer"
	elseif not text:match("^%s*/") then
		state.awaiting_agent_output = true
	end
	ctx.rpc.send(cmd)
end

function M.abort(ctx)
	ctx.state.abort_requested = true
	ctx.rpc.send({ type = "abort" })
end

function M.history(ctx)
	if not guard.if_not_active(ctx, "changing history") then
		return
	end
	ctx.rpc.send({ type = "prompt", message = "/pi-history" }, function(event)
		if not event.success then
			ctx.ui.notify(event.error or "Could not open history", vim.log.levels.ERROR)
		end
	end)
end

function M.toggle_notifications(ctx)
	ctx.rpc.send({ type = "prompt", message = "/pi-notify toggle" }, function(event)
		if not event.success then
			ctx.ui.notify(event.error or "Could not toggle notifications", vim.log.levels.ERROR)
		end
	end)
end

function M.rename_session(ctx)
	ctx.rpc.send({ type = "prompt", message = "/pi-rename" }, function(event)
		if not event.success then
			ctx.ui.notify(event.error or "Could not rename session", vim.log.levels.ERROR)
		end
	end)
end

local function reset_session_transcript_state(ctx, notice)
	local state = ctx.state
	ctx.buffer.set_modifiable(state.transcript_buf, true)
	vim.api.nvim_buf_set_lines(state.transcript_buf, 0, -1, false, {})
	ctx.buffer.set_modifiable(state.transcript_buf, false)
	ctx.transcript.clear_items()
	state.session_name = nil
	state.message_count = 0
	state.session_stats = nil
	state.todo_status = nil
	state.todo_tool_output_id = nil
	state.todo_tool_line = nil
	state.tree_leaf_id = nil
	state.spawn_runs = {}
	state.spawn_running_count = 0
	state.spawn_run_lines = {}
	state.spawn_run_output_by_id = {}
	state.is_retrying = false
	state.pending_retry_error = nil
	ctx.transcript.touch()
	ctx.transcript.refresh_ui()
	ctx.transcript.append_status(notice)
end

function M.new_session(ctx)
	require("pi-integration.targets").new_session(ctx)
end

function M.detach(ctx)
	require("pi-integration.targets").detach(ctx)
end

function M.kill(ctx)
	require("pi-integration.targets").kill(ctx)
end

return M

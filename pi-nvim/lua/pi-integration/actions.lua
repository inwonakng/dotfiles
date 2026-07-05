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
	ctx.send({ type = "get_session_stats" }, function(event)
		if event.success and event.data then
			state.session_stats = event.data
			ctx.update_transcript_statusline()

			ctx.send({ type = "get_messages" }, function(messages_event)
				if messages_event.success and messages_event.data then
					apply_session_cache_footprint(state.session_stats, messages_event.data.messages)
					ctx.update_transcript_statusline()
				end
			end)
		end
	end)
end

local function get_input(ctx)
	local state = ctx.state
	if not ctx.valid_buf(state.input_buf) then
		return ""
	end
	local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)
	return vim.trim(table.concat(lines, "\n"))
end

local function clear_input(ctx)
	local state = ctx.state
	if ctx.valid_buf(state.input_buf) then
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
		ctx.notify("Pi is retrying; wait or abort before sending another prompt.", vim.log.levels.WARN)
		return
	end
	state.abort_requested = false
	state.error_rendered_for_active_run = false
	clear_input(ctx)
	ctx.remove_status(ctx.initial_session_notice)
	ctx.remove_status(ctx.new_session_notice)
	ctx.remove_status(ctx.pending_new_session_notice)
	state.pending_user_message = text
	ctx.append_message_header("You")
	ctx.append_text(text)

	local cmd = { type = "prompt", message = text }
	if state.is_streaming then
		cmd.streamingBehavior = "steer"
	elseif not text:match("^%s*/") then
		ctx.start_assistant_placeholder()
	end
	ctx.send(cmd)
end

function M.abort(ctx)
	ctx.state.abort_requested = true
	ctx.send({ type = "abort" })
end

function M.history(ctx)
	if not guard.if_not_active(ctx, "changing history") then
		return
	end
	ctx.send({ type = "prompt", message = "/pi-history" }, function(event)
		if not event.success then
			ctx.notify(event.error or "Could not open history", vim.log.levels.ERROR)
		end
	end)
end

function M.toggle_notifications(ctx)
	ctx.send({ type = "prompt", message = "/pi-notify toggle" }, function(event)
		if not event.success then
			ctx.notify(event.error or "Could not toggle notifications", vim.log.levels.ERROR)
		end
	end)
end

function M.rename_session(ctx)
	ctx.send({ type = "prompt", message = "/pi-rename" }, function(event)
		if not event.success then
			ctx.notify(event.error or "Could not rename session", vim.log.levels.ERROR)
		end
	end)
end

local function reset_session_transcript_state(ctx, notice)
	local state = ctx.state
	ctx.set_modifiable(state.transcript_buf, true)
	vim.api.nvim_buf_set_lines(state.transcript_buf, 0, -1, false, {})
	ctx.set_modifiable(state.transcript_buf, false)
	ctx.clear_transcript_items()
	state.session_name = nil
	state.message_count = 0
	state.session_stats = nil
	state.todo_status = nil
	state.tree_leaf_id = nil
	state.is_retrying = false
	state.pending_retry_error = nil
	ctx.refresh_transcript_ui()
	ctx.append_status(notice)
end

function M.new_session(ctx)
	local state = ctx.state
	local function proceed()
		if not (state.job and state.job > 0) then
			state.pending_session_file = nil
			state.session_file = nil
			reset_session_transcript_state(ctx, ctx.pending_new_session_notice)
			return
		end

		ctx.send({ type = "new_session" }, function(event)
			if event.success then
				state.is_retrying = false
				state.pending_retry_error = nil
				reset_session_transcript_state(ctx, ctx.new_session_notice)
				ctx.send({ type = "get_state" }, function(state_event)
					if state_event.success and state_event.data then
						ctx.apply_session_state(state_event.data)
						ctx.actions.refresh_session_stats()
					end
				end)
			end
		end)
	end

	guard.confirm_abort_active_run(ctx, "Starting a new session", proceed)
end

return M

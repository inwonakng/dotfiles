local guard = require("pi-integration.utils.guard")
local runtime = require("pi-integration.runtime")

local M = {}

local function reset_conversation(ctx)
	local state = ctx.state
	state.pending_ui_requests = {}
	state.pending_user_message = nil
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
	state.assistant_block_open = false
	ctx.session.reset_outputs()
	ctx.transcript.clear_items()
	ctx.transcript.touch()
	if ctx.buffer.valid(state.transcript_buf) then
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_get_buf(win) == state.transcript_buf then
				vim.api.nvim_win_set_cursor(win, { 1, 0 })
			end
		end
		ctx.buffer.set_lines(state.transcript_buf, {}, false)
	end
end

function M.apply_state(ctx, data, new_session)
	local state = ctx.state
	if new_session or data.sessionFile ~= state.session_file then
		reset_conversation(ctx)
	end
	state.session_file = data.sessionFile
	state.pending_session_file = nil
	state.session_name = data.sessionName
	state.message_count = data.messageCount or state.message_count
	state.is_streaming = data.isStreaming or false
	state.is_compacting = data.isCompacting or false
	state.thinking_level = data.thinkingLevel or data.thinking_level or state.thinking_level
	ctx.session.set_model_metadata(data.provider or data.providerId or data.providerName, data.model or data.modelId)
	ctx.transcript.refresh_ui()
	runtime.publish()
end

function M.sync(ctx, options)
	options = options or {}
	ctx.rpc.send({ type = "get_state" }, function(event)
		if not event.success or not event.data then
			ctx.ui.notify(event.error or "Could not get Pi session state", vim.log.levels.ERROR)
			return
		end
		M.apply_state(ctx, event.data, options.new_session)
		ctx.actions.refresh_messages()
		ctx.actions.refresh_session_stats()
		if options.publish_workspace then
			ctx.rpc.send({ type = "prompt", message = "/pi-workspace-publish" })
		end
		if options.on_success then
			options.on_success()
		end
	end)
end

function M.new_session(ctx)
	local function proceed()
		if not (ctx.state.job and ctx.state.job > 0) then
			M.apply_state(ctx, { messageCount = 0 }, true)
			ctx.transcript.append_status(ctx.notices.empty_session)
			return
		end
		ctx.rpc.send({ type = "new_session" }, function(event)
			if event.success and not (event.data and event.data.cancelled) then
				M.sync(ctx, { new_session = true, publish_workspace = true })
			elseif not event.success then
				ctx.ui.notify(event.error or "Could not start a new session", vim.log.levels.ERROR)
			end
		end)
	end
	guard.confirm_abort_active_run(ctx, "Starting a new session", proceed)
end

function M.switch_session(ctx, path)
	local function proceed()
		if not (ctx.state.job and ctx.state.job > 0) then
			ctx.state.pending_session_file = path
			M.sync(ctx, {
				publish_workspace = true,
				on_success = function()
					ctx.ui.notify("Attached session")
				end,
			})
			return
		end
		ctx.rpc.send({ type = "switch_session", sessionPath = path }, function(event)
			if event.success and not (event.data and event.data.cancelled) then
				M.sync(ctx, {
					publish_workspace = true,
					on_success = function()
						ctx.ui.notify("Switched session")
					end,
				})
			else
				ctx.ui.notify("Session switch cancelled or failed", vim.log.levels.ERROR)
			end
		end)
	end
	guard.confirm_abort_active_run(ctx, "Switching sessions", proceed)
end

return M

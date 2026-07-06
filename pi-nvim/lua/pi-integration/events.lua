local M = {}

local json = require("pi-integration.utils.json")
local message_utils = require("pi-integration.utils.message")
local pi_skills = require("pi-integration.skills")

local function partial_result_text(partial_result)
	if type(partial_result) ~= "table" then
		return ""
	end
	return message_utils.extract_content_text(partial_result.content)
end

local function render_or_update_live_tool(ctx, event, text, details)
	local state = ctx.state
	local output_id, updated = ctx.tools.store_or_update_live_output(
		event.toolName or "tool",
		event.toolCallId,
		text or "",
		nil,
		details,
		nil
	)
	if updated then
		local line = state.live_tool_lines and event.toolCallId and state.live_tool_lines[event.toolCallId]
		if line then
			ctx.transcript.set_line(line, ctx.tools.summary_lines(output_id)[1])
		end
		return output_id
	end

	ctx.transcript.begin_trace_item()
	ctx.transcript.append_lines(ctx.tools.summary_lines(output_id))
	local line = ctx.transcript.line_count()
	state.live_tool_lines = state.live_tool_lines or {}
	if event.toolCallId then
		state.live_tool_lines[event.toolCallId] = line
	end
	ctx.transcript.register_item({
		kind = "tool",
		start_line = line,
		end_line = line,
		output_id = output_id,
	})
	ctx.transcript.end_trace_item()
	return output_id
end

local function run_id(run)
	if type(run) ~= "table" then
		return nil
	end
	return run.runId or run.id
end

local function shallow_copy(table_value)
	local copy = {}
	for key, value in pairs(table_value or {}) do
		copy[key] = value
	end
	return copy
end

local function find_spawn_run(ctx, id)
	if type(id) ~= "string" or id == "" then
		return nil
	end
	for _, run in ipairs(ctx.state.spawn_runs or {}) do
		if run_id(run) == id then
			return run
		end
	end
	return nil
end

local function render_or_update_spawn_run(ctx, run, progress)
	local id = run_id(run)
	if type(id) ~= "string" or id == "" then
		return false
	end
	if type(progress) == "string" and progress ~= "" then
		run = shallow_copy(run)
		run.progress = progress
	end
	ctx.transcript.touch()
	local output_id = ctx.tools.store_or_update_spawn_run_output(run, progress)
	if not output_id then
		return false
	end
	local state = ctx.state
	state.spawn_run_lines = state.spawn_run_lines or {}
	local line = state.spawn_run_lines[id]
	if line then
		ctx.transcript.set_line(line, ctx.tools.summary_lines(output_id)[1])
		return true
	end

	ctx.transcript.begin_trace_item()
	ctx.transcript.append_lines(ctx.tools.summary_lines(output_id))
	line = ctx.transcript.line_count()
	state.spawn_run_lines[id] = line
	ctx.transcript.register_item({
		kind = "tool",
		start_line = line,
		end_line = line,
		output_id = output_id,
	})
	ctx.transcript.end_trace_item()
	return true
end

local function render_spawn_runs(ctx, runs)
	if type(runs) ~= "table" then
		return false
	end
	local rendered = false
	for _, run in ipairs(runs) do
		rendered = render_or_update_spawn_run(ctx, run) or rendered
	end
	return rendered
end

local function spawn_control_action(args)
	return type(args) == "table" and type(args.action) == "string" and args.action or nil
end

local function is_coalesced_spawn_control_action(action)
	return action == "join" or action == "join_all" or action == "stop"
end

local function fallback_run(id, status)
	return {
		runId = id,
		status = status or "running",
	}
end

local function coalesce_spawn_control_start(ctx, event)
	local action = spawn_control_action(event.args)
	if not is_coalesced_spawn_control_action(action) then
		return false
	end
	ctx.state.coalesced_spawn_control_tool_calls = ctx.state.coalesced_spawn_control_tool_calls or {}
	if event.toolCallId then
		ctx.state.coalesced_spawn_control_tool_calls[event.toolCallId] = true
	end
	local args = event.args or {}
	if action == "join_all" then
		local selected = {}
		if type(args.ids) == "table" and #args.ids > 0 then
			for _, id in ipairs(args.ids) do
				table.insert(selected, find_spawn_run(ctx, id) or fallback_run(id))
			end
		else
			for _, run in ipairs(ctx.state.spawn_runs or {}) do
				if run.status == "running" or not run.joined then
					table.insert(selected, run)
				end
			end
		end
		for _, run in ipairs(selected) do
			render_or_update_spawn_run(ctx, run, "Waiting for subagent…")
		end
		return true
	end
	local id = args.id or (type(args.ids) == "table" and args.ids[1] or nil)
	if type(id) == "string" and id ~= "" then
		local progress = action == "stop" and "Stopping subagent…" or "Waiting for subagent…"
		render_or_update_spawn_run(ctx, find_spawn_run(ctx, id) or fallback_run(id), progress)
	end
	return true
end

local function coalesce_spawn_control_result(ctx, tool_call_id, text, details)
	local state = ctx.state
	local coalesced = tool_call_id and state.coalesced_spawn_control_tool_calls and state.coalesced_spawn_control_tool_calls[tool_call_id]
	if type(details) == "table" and type(details.runId) == "string" then
		render_or_update_spawn_run(ctx, details, text)
		return coalesced or true
	elseif type(details) == "table" and type(details.runs) == "table" and #details.runs > 0 then
		for _, run in ipairs(details.runs) do
			render_or_update_spawn_run(ctx, run)
		end
		return coalesced or true
	end
	return coalesced or false
end

local function spawn_custom_tool_name(message)
	if type(message) ~= "table" or message.role ~= "custom" then
		return nil
	end
	if message.customType == "spawn_completion" then
		return "spawn"
	elseif message.customType == "spawn_control_result" then
		return "spawn_control"
	end
	return nil
end

local function render_spawn_custom_tool(ctx, message)
	local name = spawn_custom_tool_name(message)
	if not name then
		return false
	end
	local text = ctx.messages.extract_text(message) or ""
	if name == "spawn" and type(message.details) == "table" and type(message.details.runId) == "string" then
		render_or_update_spawn_run(ctx, message.details, text)
		return true
	elseif name == "spawn_control" and coalesce_spawn_control_result(ctx, nil, text, message.details) then
		return true
	end
	ctx.transcript.touch()
	local output_id = ctx.tools.store_output(name, text, nil, message.details, message)
	ctx.transcript.begin_trace_item()
	ctx.transcript.append_lines(ctx.tools.summary_lines(output_id))
	local line = ctx.transcript.line_count()
	ctx.transcript.register_item({
		kind = "tool",
		start_line = line,
		end_line = line,
		output_id = output_id,
	})
	ctx.transcript.end_trace_item()
	return true
end

local function is_todo_tool_name(name)
	return name == "todowrite" or name == "todo_write"
end

local function remember_todo_tool_line(ctx, output_id, line)
	local state = ctx.state
	local output = state.tool_outputs and state.tool_outputs[output_id]
	if output and is_todo_tool_name(output.name) then
		state.todo_tool_output_id = output_id
		state.todo_tool_line = line
	end
end

local function refresh_todo_tool_line(ctx)
	local state = ctx.state
	local output_id = state.todo_tool_output_id
	local line = state.todo_tool_line
	if output_id and line and state.tool_outputs and state.tool_outputs[output_id] then
		ctx.transcript.touch()
		ctx.transcript.set_line(line, ctx.tools.summary_lines(output_id)[1])
	end
end

local function render_skill_loads(ctx, message)
	local loads = pi_skills.collect_loads(ctx.state, message)
	if #loads == 0 then
		return false
	end
	ctx.transcript.begin_trace_item()
	for _, load in ipairs(loads) do
		local output_id = ctx.skills.store_prompt(load)
		ctx.transcript.append_lines(ctx.skills.summary_lines(output_id))
		local line = ctx.transcript.line_count()
		ctx.transcript.register_item({
			kind = "skill",
			start_line = line,
			end_line = line,
			output_id = output_id,
		})
	end
	ctx.transcript.end_trace_item()
	return true
end

function M.render_message(ctx, message)
	local role = message.role or message.type or "message"
	if role == "custom" and message.display == false then
		return
	end
	if render_spawn_custom_tool(ctx, message) then
		return
	end
	local text = ctx.messages.extract_text(message)
	if not text or text == "" then
		return
	end
	ctx.transcript.touch()
	if role == "toolResult" then
		local name = message.toolName or "tool"
		local tool_call_id = message_utils.tool_call_id(message)
		if name == "spawn_control" and coalesce_spawn_control_result(ctx, tool_call_id, ctx.messages.extract_text(message) or "", message.details) then
			return
		end
		local live_output_id = ctx.tools.live_output_id(tool_call_id)
		if live_output_id then
			ctx.tools.store_or_update_live_output(name, tool_call_id, text, nil, message.details, ctx.tools.store_display and ctx.tools.store_display(message) or nil)
			local line = ctx.state.live_tool_lines and ctx.state.live_tool_lines[tool_call_id]
			if line then
				ctx.transcript.set_line(line, ctx.tools.summary_lines(live_output_id)[1])
			end
			return
		end
		local output_id = ctx.tools.store_output(name, text, nil, message.details, message)
		ctx.transcript.begin_trace_item()
		ctx.transcript.append_lines(ctx.tools.summary_lines(output_id))
		local line = ctx.transcript.line_count()
		ctx.transcript.register_item({
			kind = "tool",
			start_line = line,
			end_line = line,
			output_id = output_id,
		})
		remember_todo_tool_line(ctx, output_id, line)
		ctx.transcript.end_trace_item()
		return
	end
	ctx.transcript.append_message_header(role:gsub("^%l", string.upper))
	ctx.transcript.append_text(text)
end

local function send_extension_ui_response(ctx, id, response)
	response.type = "extension_ui_response"
	response.id = id
	ctx.rpc.send(response)
end

local function decode_approval_payload(message)
	if type(message) ~= "string" or message == "" then
		return nil
	end
	local decoded = json.decode_object(message)
	if not decoded or decoded.kind ~= "pi_approval_preview" then
		return nil
	end
	return decoded
end

local function approval_preview_item(payload)
	local preview = type(payload.preview) == "string" and payload.preview or ""
	local lines = vim.split(preview, "\n", { plain = true })
	if #lines == 0 then
		lines = { "" }
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = payload.preview_filetype or "text"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	return {
		buf = buf,
		pos = { 1, 1 },
	}
end

local function confirm_with_preview(ctx, event)
	local payload = decode_approval_payload(event.message)
	if not payload then
		return false
	end

	local prompt = payload.tool and ("Allow " .. payload.tool .. "?") or (event.title or "Pi confirm")
	vim.ui.select({ "Allow", "Deny" }, {
		prompt = prompt,
		kind = "pi_approval",
		preview_item = function()
			return approval_preview_item(payload)
		end,
	}, function(choice)
		send_extension_ui_response(ctx, event.id, { confirmed = choice == "Allow" })
	end)
	return true
end

local function update_access_mode_from_status(ctx, text)
	if type(text) ~= "string" then
		return
	end
	local mode = text:match("Mode:%s*(%w+)")
	if mode and ctx.access.is_mode(mode) then
		ctx.state.access_mode = mode
		ctx.transcript.refresh_ui()
	end
end

local function update_spawn_runs_from_status(ctx, text)
	local payload = type(text) == "string" and json.decode_object(text) or nil
	if type(payload) ~= "table" then
		return
	end
	ctx.state.spawn_running_count = tonumber(payload.running) or 0
	ctx.state.spawn_runs = type(payload.runs) == "table" and payload.runs or {}
	render_spawn_runs(ctx, ctx.state.spawn_runs)
	ctx.transcript.refresh_ui()
end

function M.handle_extension_ui_request(ctx, event)
	local state = ctx.state
	if event.method == "set_editor_text" and type(event.text) == "string" and ctx.buffer.valid(state.input_buf) then
		vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, vim.split(event.text, "\n", { plain = true }))
	elseif event.method == "notify" then
		ctx.ui.notify(event.message or vim.inspect(event))
	elseif event.method == "setStatus" then
		if event.statusKey == "pi-access-mode" then
			update_access_mode_from_status(ctx, event.statusText)
		elseif event.statusKey == "pi-history-changed" then
			ctx.actions.refresh_messages()
		elseif event.statusKey == "pi-session-title" then
			state.session_name = event.statusText
			ctx.transcript.refresh_ui()
		elseif event.statusKey == "pi-tree-leaf" then
			state.tree_leaf_id = event.statusText
		elseif event.statusKey == "pi-todos" then
			state.todo_status = event.statusText
			refresh_todo_tool_line(ctx)
		elseif event.statusKey == "pi-notifications" then
			state.notification_status = event.statusText
			ctx.transcript.refresh_ui()
		elseif event.statusKey == "pi-spawn-runs" then
			update_spawn_runs_from_status(ctx, event.statusText)
		end
	elseif event.method == "setTitle" and type(event.title) == "string" then
		vim.opt.titlestring = event.title
		vim.opt.title = true
	elseif event.method == "select" then
		vim.ui.select(event.options or {}, { prompt = event.title or "Pi select" }, function(choice)
			if choice then
				send_extension_ui_response(ctx, event.id, { value = choice })
			else
				send_extension_ui_response(ctx, event.id, { cancelled = true })
			end
		end)
	elseif event.method == "confirm" then
		if confirm_with_preview(ctx, event) then
			return
		end
		local prompt = event.title or "Pi confirm"
		if type(event.message) == "string" and event.message ~= "" then
			prompt = prompt .. "\n" .. event.message
		end
		vim.ui.select({ "Yes", "No" }, { prompt = prompt }, function(choice)
			send_extension_ui_response(ctx, event.id, { confirmed = choice == "Yes" })
		end)
	elseif event.method == "input" then
		vim.ui.input({ prompt = event.title or "Pi input", default = event.placeholder or "" }, function(value)
			if value then
				send_extension_ui_response(ctx, event.id, { value = value })
			else
				send_extension_ui_response(ctx, event.id, { cancelled = true })
			end
		end)
	elseif event.method == "editor" then
		ctx.ui.notify("Pi requested an editor UI, which pi-nvim does not support yet", vim.log.levels.WARN)
		send_extension_ui_response(ctx, event.id, { cancelled = true })
	end
end

function M.handle_message_update(ctx, event)
	local state = ctx.state
	local update = event.assistantMessageEvent or {}

	local function render_active_thinking_if_visible(streaming)
		local output_id = state.active_thinking_output_id
		if not output_id or state.active_thinking_line then
			return
		end
		local text = ctx.thinking.text(output_id) or ""
		if vim.trim(text) == "" then
			return
		end
		if not state.current_message_started then
			ctx.transcript.clear_assistant_placeholder()
			ctx.transcript.append_message_header("Assistant")
			state.current_message_started = true
		end
		state.current_thinking_rendered = true
		ctx.transcript.begin_trace_item()
		ctx.transcript.append_lines(ctx.thinking.summary_lines(output_id, streaming))
		local line = ctx.transcript.line_count()
		state.active_thinking_line = line
		ctx.transcript.register_item({
			kind = "thinking",
			start_line = line,
			end_line = line,
			output_id = output_id,
		})
		ctx.transcript.end_trace_item()
	end

	if update.type == "text_start" then
		if not state.current_message_started then
			ctx.transcript.clear_assistant_placeholder()
			ctx.transcript.append_message_header("Assistant")
		end
		state.current_message_started = true
	elseif update.type == "text_delta" then
		if not state.current_message_started then
			ctx.transcript.clear_assistant_placeholder()
			state.current_message_started = true
			ctx.transcript.append_message_header("Assistant")
		end
		ctx.transcript.append_text(update.delta or "")
	elseif update.type == "thinking_start" and ctx.config.show_thinking then
		state.active_thinking_output_id = ctx.thinking.store_output("")
		state.active_thinking_line = nil
	elseif update.type == "thinking_delta" and ctx.config.show_thinking then
		if state.active_thinking_output_id then
			ctx.thinking.append_output(state.active_thinking_output_id, update.delta or "")
			render_active_thinking_if_visible(true)
		end
	elseif update.type == "thinking_end" and ctx.config.show_thinking then
		if state.active_thinking_output_id then
			local text = ctx.thinking.text(state.active_thinking_output_id) or ""
			local final_content = update.content or ""
			if vim.trim(text) == "" and vim.trim(final_content) ~= "" then
				ctx.thinking.append_output(state.active_thinking_output_id, final_content)
			end
			render_active_thinking_if_visible(false)
			if state.active_thinking_line then
				local summary = ctx.thinking.summary_lines(state.active_thinking_output_id, false)[1]
				ctx.transcript.set_line(state.active_thinking_line, summary)
			end
		end
		state.active_thinking_output_id = nil
		state.active_thinking_line = nil
	elseif update.type == "toolcall_start" then
		ctx.transcript.clear_assistant_placeholder_spinner()
		state.current_message_started = true
	elseif update.type == "toolcall_delta" then
		-- Tool-call deltas are usually raw JSON arguments. For multiline edits this
		-- can be thousands of characters streamed token-by-token before the useful
		-- approval preview/diff appears, making the UI feel much slower than Codex.
		-- Ignore the raw argument stream and let tool_execution_* plus approval
		-- previews render the meaningful result.
		return
	elseif update.type == "toolcall_end" then
		return
	elseif update.type == "error" then
		-- Provider/transport errors may be followed by an automatic retry. The
		-- retry decision is only known at agent_end, so keep the error pending
		-- instead of rendering a scary final error immediately.
		state.pending_retry_error = ctx.rpc.event_error_text(update) or "unknown"
	end
end

function M.handle_event(ctx, event)
	local state = ctx.state
	if event.type == "response" then
		ctx.rpc.handle_response(event)
	elseif event.type == "agent_start" then
		state.is_streaming = true
		state.is_retrying = false
		state.pending_retry_error = nil
		state.current_message_started = false
		state.current_thinking_rendered = false
		state.active_thinking_output_id = nil
		state.active_thinking_line = nil
		state.error_rendered_for_active_run = false
		ctx.ui.notify("Pi is working")
	elseif event.type == "agent_end" then
		state.is_streaming = false
		state.current_message_started = false
		state.current_thinking_rendered = false
		state.active_thinking_output_id = nil
		state.active_thinking_line = nil
		local message = ctx.rpc.event_error_text(event)
		if event.willRetry then
			state.is_retrying = true
			ctx.transcript.clear_assistant_placeholder()
			state.abort_requested = false
			ctx.actions.refresh_session_stats()
			return
		end
		state.is_retrying = false
		state.pending_retry_error = nil
		if message and not state.error_rendered_for_active_run then
			ctx.transcript.render_error_message("Agent Error", message)
		elseif ctx.transcript.assistant_placeholder_active() and state.abort_requested then
			ctx.transcript.clear_assistant_placeholder()
		elseif ctx.transcript.assistant_placeholder_active() and not state.error_rendered_for_active_run then
			ctx.transcript.render_error_message(
				"Agent Error",
				ctx.rpc.recent_stderr_text() or "Agent stopped before returning a message. No error details were provided."
			)
		else
			ctx.transcript.clear_assistant_placeholder()
		end
		state.abort_requested = false
		ctx.transcript.touch()
		ctx.transcript.refresh_ui()
		ctx.actions.refresh_session_stats()
		ctx.ui.notify("Pi finished")
	elseif event.type == "auto_retry_start" then
		state.is_retrying = true
		state.pending_retry_error = event.errorMessage or state.pending_retry_error
		ctx.ui.notify(
			"Pi retrying after transient error ("
				.. tostring(event.attempt or "?")
				.. "/"
				.. tostring(event.maxAttempts or "?")
				.. ")"
		)
	elseif event.type == "auto_retry_end" then
		state.is_retrying = false
		state.pending_retry_error = nil
		if event.success == false and not state.error_rendered_for_active_run then
			ctx.transcript.render_error_message("Agent Error", event.finalError or "Retry failed")
			ctx.transcript.touch()
			ctx.transcript.refresh_ui()
		end
	elseif event.type == "message_update" then
		M.handle_message_update(ctx, event)
	elseif event.type == "message_end" then
		if
			event.message
			and event.message.role == "user"
			and state.pending_user_message
			and vim.trim(ctx.messages.extract_text(event.message) or "") == state.pending_user_message
		then
			state.pending_user_message = nil
			return
		end
		if event.message and event.message.role == "toolResult" then
			if pi_skills.tool_result_skill_name(state, event.message) then
				ctx.skills.apply_tool_result(event.message)
				return
			end
			M.render_message(ctx, event.message)
		elseif event.message and event.message.role == "assistant" then
			ctx.tools.record_calls(event.message)
			if not state.current_message_started and not state.current_thinking_rendered then
				M.render_message(ctx, event.message)
			end
			render_skill_loads(ctx, event.message)
		elseif event.message and not state.current_message_started and not state.current_thinking_rendered then
			M.render_message(ctx, event.message)
		end
	elseif event.type == "tool_execution_start" then
		ctx.transcript.clear_assistant_placeholder_spinner()
		state.current_message_started = true
		if event.toolName == "edit" or event.toolName == "write" or event.toolName == "bash" then
			ctx.tools.record_execution_call(event.toolName, event.toolCallId, event.args)
		end
		if event.toolName == "spawn" then
			render_or_update_live_tool(ctx, event, "Subagent starting…", { status = "running" })
		elseif event.toolName == "spawn_control" then
			if not coalesce_spawn_control_start(ctx, event) then
				render_or_update_live_tool(ctx, event, "Subagent starting…", { status = "running" })
			end
		end
		-- Non-spawn tool output is rendered from the final toolResult message. Rendering
		-- every tool_execution_* stream creates empty/duplicate tool blocks for tools
		-- that only publish their output at completion.
		return
	elseif event.type == "tool_execution_update" then
		if event.toolName == "spawn" then
			local partial = type(event.partialResult) == "table" and event.partialResult or {}
			render_or_update_live_tool(ctx, event, partial_result_text(partial), partial.details or { status = "running" })
		elseif event.toolName == "spawn_control" then
			local partial = type(event.partialResult) == "table" and event.partialResult or {}
			if not coalesce_spawn_control_result(ctx, event.toolCallId, partial_result_text(partial), partial.details) then
				render_or_update_live_tool(ctx, event, partial_result_text(partial), partial.details or { status = "running" })
			end
		end
		return
	elseif event.type == "tool_execution_end" then
		if event.toolName == "spawn" then
			local result = type(event.result) == "table" and event.result or {}
			render_or_update_live_tool(ctx, event, message_utils.extract_content_text(result.content), result.details or {})
		elseif event.toolName == "spawn_control" then
			local result = type(event.result) == "table" and event.result or {}
			if not coalesce_spawn_control_result(ctx, event.toolCallId, message_utils.extract_content_text(result.content), result.details) then
				render_or_update_live_tool(ctx, event, message_utils.extract_content_text(result.content), result.details or {})
			end
		end
		return
	elseif event.type == "queue_update" then
		local count = event.pendingMessageCount or event.count
		if count then
			ctx.ui.notify("Pi queue: " .. tostring(count) .. " pending")
		end
	elseif event.type == "session_info_changed" then
		state.session_name = event.name
		ctx.transcript.refresh_ui()
	elseif event.type == "extension_ui_request" then
		M.handle_extension_ui_request(ctx, event)
	end
end

return M

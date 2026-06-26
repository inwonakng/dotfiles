local M = {}

function M.render_message(ctx, message)
	local role = message.role or message.type or "message"
	local text = ctx.extract_text(message)
	if not text or text == "" then
		return
	end
	if role == "toolResult" then
		local name = message.toolName or "tool"
		local output_id = ctx.store_tool_output(name, text, nil, message.details)
		ctx.remove_pending_transcript_item_separator()
		ctx.append_lines(ctx.tool_output_summary_lines(output_id))
		local line = ctx.transcript_line_count()
		ctx.register_transcript_item({
			kind = "tool",
			start_line = line,
			end_line = line,
			output_id = output_id,
		})
		ctx.append_transcript_item_separator()
		return
	end
	ctx.append_message_header(role:gsub("^%l", string.upper))
	ctx.append_text(text)
end

local function send_extension_ui_response(ctx, id, response)
	response.type = "extension_ui_response"
	response.id = id
	ctx.send(response)
end

local function decode_approval_payload(message)
	if type(message) ~= "string" or message == "" then
		return nil
	end
	local ok, decoded
	if vim.json and vim.json.decode then
		ok, decoded = pcall(vim.json.decode, message)
	else
		ok, decoded = pcall(vim.fn.json_decode, message)
	end
	if not ok or type(decoded) ~= "table" or decoded.kind ~= "pi_approval_preview" then
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
	if mode and ctx.is_access_mode(mode) then
		ctx.state.access_mode = mode
		ctx.refresh_transcript_ui()
	end
end

function M.handle_extension_ui_request(ctx, event)
	local state = ctx.state
	if event.method == "set_editor_text" and type(event.text) == "string" and ctx.valid_buf(state.input_buf) then
		vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, vim.split(event.text, "\n", { plain = true }))
	elseif event.method == "notify" then
		ctx.notify(event.message or vim.inspect(event))
	elseif event.method == "setStatus" then
		if event.statusKey == "pi-access-mode" then
			update_access_mode_from_status(ctx, event.statusText)
		elseif event.statusKey == "pi-history-changed" then
			ctx.actions.refresh_messages()
		elseif event.statusKey == "pi-session-title" then
			state.session_name = event.statusText
			ctx.refresh_transcript_ui()
		elseif event.statusKey == "pi-tree-leaf" then
			state.tree_leaf_id = event.statusText
		elseif event.statusKey == "pi-todos" then
			state.todo_status = event.statusText
			ctx.refresh_transcript_ui()
		elseif event.statusKey == "pi-notifications" then
			state.notification_status = event.statusText
			ctx.refresh_transcript_ui()
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
		ctx.notify("Pi requested an editor UI, which pi-nvim does not support yet", vim.log.levels.WARN)
		send_extension_ui_response(ctx, event.id, { cancelled = true })
	end
end

function M.handle_message_update(ctx, event)
	local state = ctx.state
	local update = event.assistantMessageEvent or {}

	if update.type == "text_start" then
		if not state.current_message_started then
			ctx.clear_assistant_placeholder()
			ctx.append_message_header("Assistant")
		end
		state.current_message_started = true
	elseif update.type == "text_delta" then
		if not state.current_message_started then
			ctx.clear_assistant_placeholder()
			state.current_message_started = true
			ctx.append_message_header("Assistant")
		end
		ctx.append_text(update.delta or "")
	elseif update.type == "thinking_start" and ctx.config.show_thinking then
		if not state.current_message_started then
			ctx.clear_assistant_placeholder()
			ctx.append_message_header("Assistant")
			state.current_message_started = true
		end
		local output_id = ctx.store_thinking_output("")
		state.active_thinking_output_id = output_id
		state.current_thinking_rendered = true
		ctx.append_lines(ctx.thinking_output_summary_lines(output_id, true))
		local line = ctx.transcript_line_count()
		state.active_thinking_line = line
		ctx.register_transcript_item({
			kind = "thinking",
			start_line = line,
			end_line = line,
			output_id = output_id,
		})
		ctx.append_transcript_item_separator()
	elseif update.type == "thinking_delta" and ctx.config.show_thinking then
		if state.active_thinking_output_id then
			ctx.append_thinking_output(state.active_thinking_output_id, update.delta or "")
		end
	elseif update.type == "thinking_end" and ctx.config.show_thinking then
		if state.active_thinking_output_id and state.active_thinking_line then
			local summary = ctx.thinking_output_summary_lines(state.active_thinking_output_id, false)[1]
			ctx.set_transcript_line(state.active_thinking_line, summary)
		end
		state.active_thinking_output_id = nil
		state.active_thinking_line = nil
	elseif update.type == "toolcall_start" then
		ctx.clear_assistant_placeholder_spinner()
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
		ctx.render_error_message("Agent Error", ctx.event_error_text(update) or "unknown")
	end
end

function M.handle_event(ctx, event)
	local state = ctx.state
	if event.type == "response" then
		ctx.handle_response(event)
	elseif event.type == "agent_start" then
		state.is_streaming = true
		state.current_message_started = false
		state.current_thinking_rendered = false
		state.active_thinking_output_id = nil
		state.active_thinking_line = nil
		state.error_rendered_for_active_run = false
		ctx.notify("Pi is working")
	elseif event.type == "agent_end" then
		state.is_streaming = false
		state.current_message_started = false
		state.current_thinking_rendered = false
		state.active_thinking_output_id = nil
		state.active_thinking_line = nil
		local message = ctx.event_error_text(event)
		if message and not state.error_rendered_for_active_run then
			ctx.render_error_message("Agent Error", message)
		elseif ctx.assistant_placeholder_active() and state.abort_requested then
			ctx.clear_assistant_placeholder()
		elseif ctx.assistant_placeholder_active() and not state.error_rendered_for_active_run then
			ctx.render_error_message(
				"Agent Error",
				ctx.recent_stderr_text() or "Agent stopped before returning a message. No error details were provided."
			)
		else
			ctx.clear_assistant_placeholder()
		end
		state.abort_requested = false
		ctx.actions.refresh_session_stats()
		ctx.notify("Pi finished")
	elseif event.type == "message_update" then
		M.handle_message_update(ctx, event)
	elseif event.type == "message_end" then
		if
			event.message
			and event.message.role == "user"
			and state.pending_user_message
			and vim.trim(ctx.extract_text(event.message) or "") == state.pending_user_message
		then
			state.pending_user_message = nil
			return
		end
		if event.message and event.message.role == "toolResult" then
			M.render_message(ctx, event.message)
		elseif event.message and not state.current_message_started and not state.current_thinking_rendered then
			M.render_message(ctx, event.message)
		end
	elseif event.type == "tool_execution_start" then
		ctx.clear_assistant_placeholder_spinner()
		state.current_message_started = true
		-- Tool output is rendered from the final toolResult message. Rendering the
		-- tool_execution_* stream as well creates an empty/duplicate tool block for
		-- tools that only publish their output at completion.
		return
	elseif event.type == "tool_execution_update" then
		return
	elseif event.type == "tool_execution_end" then
		return
	elseif event.type == "queue_update" then
		local count = event.pendingMessageCount or event.count
		if count then
			ctx.notify("Pi queue: " .. tostring(count) .. " pending")
		end
	elseif event.type == "session_info_changed" then
		state.session_name = event.name
		ctx.refresh_transcript_ui()
	elseif event.type == "extension_ui_request" then
		M.handle_extension_ui_request(ctx, event)
	end
end

return M

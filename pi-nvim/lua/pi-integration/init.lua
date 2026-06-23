local M = {}

local state = {
	job = nil,
	stdout_pending = "",
	stderr_pending = "",
	next_id = 0,
	callbacks = {},
	transcript_buf = nil,
	input_buf = nil,
	transcript_win = nil,
	input_win = nil,
	help_buf = nil,
	help_win = nil,
	is_streaming = false,
	access_mode = "readonly",
	current_message_started = false,
	session_file = nil,
	session_name = nil,
	message_count = 0,
	provider = nil,
	model_id = nil,
	last_updated = nil,
	transcript_refresh_scheduled = false,
	pending_user_message = nil,
	placeholder_timer = nil,
	placeholder_start_line = nil,
	placeholder_line = nil,
	placeholder_tick = 1,
	abort_requested = false,
	error_rendered_for_active_run = false,
	last_stderr_lines = {},
	active_tool_fold = nil,
	tool_folds = {},
}

M.config = {
	binary = "pi",
	agent_dir = nil,
	provider = nil,
	model = nil,
	session_dir = nil,
	show_thinking = false,
	show_stderr = false,
	access_modes = { "readonly", "write" },
	session_dirs = {
		"~/.pi/agent/sessions",
		"~/.pi/sessions",
	},
}

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "pi-nvim" })
end

local function valid_buf(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

local function set_modifiable(buf, value)
	vim.api.nvim_set_option_value("modifiable", value, { buf = buf })
end

local function yaml_value(value)
	if value == nil or value == "" then
		return "null"
	end
	local text = tostring(value):gsub("\\", "\\\\"):gsub('"', '\\"')
	return '"' .. text .. '"'
end

local function session_label()
	if not state.session_file or state.session_file == "" then
		return nil
	end
	return vim.fn.fnamemodify(state.session_file, ":t")
end

local function normalize_model_metadata(provider, model)
	local model_id = model
	if type(model) == "table" then
		provider = provider or model.provider or model.providerName or model.providerId
		model_id = model.modelId or model.id or model.name
	end
	if (not provider) and type(model_id) == "string" and model_id:find("/", 1, true) then
		provider, model_id = model_id:match("^([^/]+)/(.+)$")
	end
	return provider, model_id
end

local function set_model_metadata(provider, model)
	provider, model = normalize_model_metadata(provider, model)
	state.provider = provider or state.provider
	state.model_id = model or state.model_id
end

local function metadata_lines()
	return {
		"---",
		"title: " .. yaml_value(state.session_name or "Pi Session"),
		"model: " .. yaml_value(state.model_id or M.config.model),
		"provider: " .. yaml_value(state.provider or M.config.provider),
		"access: " .. yaml_value(state.access_mode),
		"session: " .. yaml_value(session_label()),
		"cwd: " .. yaml_value(vim.fn.getcwd()),
		"last_updated: " .. yaml_value(state.last_updated),
		"---",
	}
end

local function metadata_end()
	if not valid_buf(state.transcript_buf) then
		return nil
	end
	local first = vim.api.nvim_buf_get_lines(state.transcript_buf, 0, 1, false)[1]
	if first ~= "---" then
		return nil
	end
	local lines = vim.api.nvim_buf_get_lines(state.transcript_buf, 1, -1, false)
	for index, line in ipairs(lines) do
		if line == "---" then
			return index + 1
		end
	end
	return nil
end

local function update_metadata()
	if not valid_buf(state.transcript_buf) then
		return
	end
	set_modifiable(state.transcript_buf, true)
	local end_line = metadata_end()
	local lines = metadata_lines()
	if end_line then
		vim.api.nvim_buf_set_lines(state.transcript_buf, 0, end_line, false, lines)
	else
		vim.api.nvim_buf_set_lines(state.transcript_buf, 0, 0, false, lines)
	end
	set_modifiable(state.transcript_buf, false)
end

local function has_transcript_body()
	local end_line = metadata_end()
	if not end_line then
		return false
	end
	local lines = vim.api.nvim_buf_get_lines(state.transcript_buf, end_line, -1, false)
	for _, line in ipairs(lines) do
		if line ~= "" then
			return true
		end
	end
	return false
end

local function render_transcript()
	if not valid_buf(state.transcript_buf) then
		return
	end
	if not (state.transcript_win and vim.api.nvim_win_is_valid(state.transcript_win)) then
		return
	end

	local render_markdown = package.loaded["render-markdown"]
	if not (type(render_markdown) == "table" and type(render_markdown.render) == "function") then
		return
	end

	vim.schedule(function()
		if valid_buf(state.transcript_buf) and state.transcript_win and vim.api.nvim_win_is_valid(state.transcript_win) then
			render_markdown.render({ buf = state.transcript_buf, win = state.transcript_win, event = "PiNvim" })
		end
	end)
end

local function refresh_transcript_ui()
	state.last_updated = os.date("%Y-%m-%d %H:%M:%S %z")
	update_metadata()
	render_transcript()
end

local function apply_session_state(data)
	state.session_file = data.sessionFile
	state.session_name = data.sessionName
	state.message_count = data.messageCount or state.message_count
	state.is_streaming = data.isStreaming or false
	set_model_metadata(data.provider or data.providerId or data.providerName, data.model or data.modelId)
	refresh_transcript_ui()
end

local function schedule_transcript_refresh()
	if state.transcript_refresh_scheduled then
		return
	end
	state.transcript_refresh_scheduled = true
	vim.defer_fn(function()
		state.transcript_refresh_scheduled = false
		if valid_buf(state.transcript_buf) then
			refresh_transcript_ui()
		end
	end, 30)
end

local function transcript_line_count()
	if not valid_buf(state.transcript_buf) then
		return 0
	end
	return vim.api.nvim_buf_line_count(state.transcript_buf)
end

local function with_transcript_win(callback)
	if not (state.transcript_win and vim.api.nvim_win_is_valid(state.transcript_win)) then
		return
	end
	vim.api.nvim_win_call(state.transcript_win, callback)
end

local function delete_tool_folds()
	state.tool_folds = {}
	state.active_tool_fold = nil
	with_transcript_win(function()
		vim.cmd("normal! zE")
	end)
end

local function append_lines(lines)
	if not valid_buf(state.transcript_buf) then
		return
	end
	if type(lines) == "string" then
		lines = vim.split(lines, "\n", { plain = true })
	end
	set_modifiable(state.transcript_buf, true)
	local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
	local last_line = vim.api.nvim_buf_get_lines(state.transcript_buf, line_count - 1, line_count, false)[1]
	if lines[1] == "" and last_line == "" then
		table.remove(lines, 1)
	end
	if line_count == 1 and vim.api.nvim_buf_get_lines(state.transcript_buf, 0, 1, false)[1] == "" then
		vim.api.nvim_buf_set_lines(state.transcript_buf, 0, 1, false, lines)
	else
		vim.api.nvim_buf_set_lines(state.transcript_buf, line_count, line_count, false, lines)
	end
	set_modifiable(state.transcript_buf, false)
	if state.transcript_win and vim.api.nvim_win_is_valid(state.transcript_win) then
		vim.api.nvim_win_set_cursor(state.transcript_win, { vim.api.nvim_buf_line_count(state.transcript_buf), 0 })
	end
	schedule_transcript_refresh()
end

local function append_text(text)
	if not valid_buf(state.transcript_buf) or text == nil or text == "" then
		return
	end

	local parts = vim.split(text, "\n", { plain = true })
	set_modifiable(state.transcript_buf, true)

	local last = vim.api.nvim_buf_line_count(state.transcript_buf)
	local current = vim.api.nvim_buf_get_lines(state.transcript_buf, last - 1, last, false)[1] or ""
	vim.api.nvim_buf_set_lines(state.transcript_buf, last - 1, last, false, { current .. parts[1] })

	if #parts > 1 then
		local rest = {}
		for i = 2, #parts do
			table.insert(rest, parts[i])
		end
		vim.api.nvim_buf_set_lines(state.transcript_buf, last, last, false, rest)
	end

	set_modifiable(state.transcript_buf, false)
	if state.transcript_win and vim.api.nvim_win_is_valid(state.transcript_win) then
		vim.api.nvim_win_set_cursor(state.transcript_win, { vim.api.nvim_buf_line_count(state.transcript_buf), 0 })
	end
	schedule_transcript_refresh()
end

local function append_message_header(role)
	if has_transcript_body() then
		append_lines({ "", "---", "", "## " .. role, "", "" })
	else
		append_lines({ "", "## " .. role, "", "" })
	end
end

local function append_status(text)
	append_lines({ "> " .. text })
end

local function create_tool_fold(start_line, end_line)
	if end_line <= start_line then
		return
	end

	table.insert(state.tool_folds, {
		start_line = start_line,
		end_line = end_line,
	})

	with_transcript_win(function()
		local cursor = vim.api.nvim_win_get_cursor(state.transcript_win)
		vim.cmd(string.format("%d,%dfold", start_line, end_line))
		vim.api.nvim_win_set_cursor(state.transcript_win, { start_line, 0 })
		vim.cmd("normal! zc")
		local line_count = transcript_line_count()
		if cursor[1] <= line_count then
			vim.api.nvim_win_set_cursor(state.transcript_win, cursor)
		else
			vim.api.nvim_win_set_cursor(state.transcript_win, { line_count, 0 })
		end
	end)
end

local function start_tool_fold()
	state.active_tool_fold = {
		start_line = transcript_line_count(),
	}
end

local function finish_tool_fold()
	if not state.active_tool_fold then
		return
	end

	local tool_fold = state.active_tool_fold
	state.active_tool_fold = nil
	create_tool_fold(tool_fold.start_line, transcript_line_count())
end

local function line_in_tool_fold(line)
	for _, tool_fold in ipairs(state.tool_folds) do
		local header_line = math.max(1, tool_fold.start_line - 1)
		if line >= header_line and line <= tool_fold.end_line then
			return tool_fold
		end
	end
	return nil
end

local function toggle_tool_fold()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local tool_fold = line_in_tool_fold(cursor[1])
	if not tool_fold then
		return false
	end
	vim.api.nvim_win_set_cursor(0, { tool_fold.start_line, 0 })
	vim.cmd("normal! za")
	vim.api.nvim_win_set_cursor(0, cursor)
	return true
end

local function stop_placeholder_timer()
	if state.placeholder_timer then
		state.placeholder_timer:stop()
		state.placeholder_timer:close()
		state.placeholder_timer = nil
	end
end

local function set_placeholder_line(text)
	if not valid_buf(state.transcript_buf) or not state.placeholder_line then
		return
	end
	local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
	if state.placeholder_line < 1 or state.placeholder_line > line_count then
		return
	end
	set_modifiable(state.transcript_buf, true)
	vim.api.nvim_buf_set_lines(state.transcript_buf, state.placeholder_line - 1, state.placeholder_line, false, { text })
	set_modifiable(state.transcript_buf, false)
	schedule_transcript_refresh()
end

local function clear_assistant_placeholder()
	stop_placeholder_timer()
	if not valid_buf(state.transcript_buf) or not state.placeholder_start_line or not state.placeholder_line then
		state.placeholder_start_line = nil
		state.placeholder_line = nil
		return
	end
	local start_line = state.placeholder_start_line - 1
	local end_line = state.placeholder_line
	local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
	if start_line < 0 or end_line > line_count then
		state.placeholder_start_line = nil
		state.placeholder_line = nil
		return
	end
	set_modifiable(state.transcript_buf, true)
	vim.api.nvim_buf_set_lines(state.transcript_buf, start_line, end_line, false, {})
	set_modifiable(state.transcript_buf, false)
	state.placeholder_start_line = nil
	state.placeholder_line = nil
	schedule_transcript_refresh()
end

local function start_assistant_placeholder()
	clear_assistant_placeholder()
	local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
	local replacing_empty =
		line_count == 1 and vim.api.nvim_buf_get_lines(state.transcript_buf, 0, 1, false)[1] == ""
	local lines = has_transcript_body() and { "", "---", "", "## Assistant", "", "⠋" }
		or { "", "## Assistant", "", "⠋" }
	state.placeholder_start_line = replacing_empty and 1 or (line_count + 1)
	append_lines(lines)
	state.placeholder_line = vim.api.nvim_buf_line_count(state.transcript_buf)
	state.placeholder_tick = 1

	local frames = {
		"⠋",
		"⠙",
		"⠩",
		"⠸",
		"⠼",
		"⠴",
		"⠦",
		"⠧",
	}
	local timer = vim.uv.new_timer()
	state.placeholder_timer = timer
	timer:start(250, 250, vim.schedule_wrap(function()
		if state.placeholder_timer ~= timer then
			return
		end
		state.placeholder_tick = (state.placeholder_tick % #frames) + 1
		set_placeholder_line(frames[state.placeholder_tick])
	end))
end

local function assistant_placeholder_active()
	return state.placeholder_start_line ~= nil and state.placeholder_line ~= nil
end

local function render_error_message(title, message)
	clear_assistant_placeholder()
	state.error_rendered_for_active_run = true
	append_message_header(title)
	append_lines({ message })
end

local function event_error_text(event)
	if type(event) ~= "table" then
		return nil
	end

	for _, key in ipairs({ "error", "message", "reason" }) do
		if type(event[key]) == "string" and event[key] ~= "" then
			return event[key]
		end
	end

	return nil
end

local function recent_stderr_text()
	if #state.last_stderr_lines == 0 then
		return nil
	end
	return table.concat(state.last_stderr_lines, "\n")
end

local function encode_json(obj)
	if vim.json and vim.json.encode then
		return vim.json.encode(obj)
	end
	return vim.fn.json_encode(obj)
end

local function decode_json(line)
	local ok, decoded
	if vim.json and vim.json.decode then
		ok, decoded = pcall(vim.json.decode, line)
	else
		ok, decoded = pcall(vim.fn.json_decode, line)
	end
	if ok then
		return decoded
	end
	render_error_message("Pi Error", "Bad JSON from pi: " .. line)
	return nil
end

local function next_request_id()
	state.next_id = state.next_id + 1
	return "pi-nvim-" .. tostring(state.next_id)
end

local function send(cmd, callback)
	M.start()
	if not state.job or state.job <= 0 then
		render_error_message("Pi Error", "Could not start pi. Is `pi` on PATH?")
		return
	end

	if callback then
		cmd.id = cmd.id or next_request_id()
		state.callbacks[cmd.id] = callback
	end

	local line = encode_json(cmd) .. "\n"
	local sent = vim.fn.chansend(state.job, line)
	if sent == 0 then
		if cmd.id then
			state.callbacks[cmd.id] = nil
		end
		render_error_message("Pi Error", "Could not send request to pi; the RPC channel is closed.")
	end
end

local function get_input()
	if not valid_buf(state.input_buf) then
		return ""
	end
	local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)
	return vim.trim(table.concat(lines, "\n"))
end

local function clear_input()
	if valid_buf(state.input_buf) then
		vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "" })
	end
end

local function is_access_mode(mode)
	for _, candidate in ipairs(M.config.access_modes or {}) do
		if candidate == mode then
			return true
		end
	end
	return false
end

local function model_label(model)
	if type(model) ~= "table" then
		return tostring(model)
	end
	local provider = model.provider or model.providerName or model.providerId
	local id = model.modelId or model.id or model.name
	local display = model.displayName or model.label

	if display and provider and id then
		return string.format("%s (%s/%s)", display, provider, id)
	end
	if provider and id then
		return provider .. "/" .. id
	end
	return display or id or vim.inspect(model)
end

local function model_parts(model)
	local provider = model.provider or model.providerName or model.providerId
	local model_id = model.modelId or model.id or model.name

	if (not provider) and type(model_id) == "string" and model_id:find("/", 1, true) then
		provider, model_id = model_id:match("^([^/]+)/(.+)$")
	end

	return provider, model_id
end

local function extract_text(message)
	if type(message) ~= "table" then
		return nil
	end
	if type(message.text) == "string" then
		return message.text
	end
	if type(message.message) == "string" then
		return message.message
	end
	if type(message.content) == "string" then
		return message.content
	end
	if type(message.content) == "table" then
		local chunks = {}
		for _, item in ipairs(message.content) do
			if type(item) == "string" then
				table.insert(chunks, item)
			elseif type(item) == "table" then
				table.insert(chunks, item.text or item.content or item.delta or "")
			end
		end
		return table.concat(chunks, "")
	end
	return nil
end

local function render_message(message)
	local role = message.role or message.type or "message"
	local text = extract_text(message)
	if not text or text == "" then
		return
	end
	if role == "toolResult" then
		local name = message.toolName or "tool"
		append_lines({ "", "### Tool: " .. name, "" })
		start_tool_fold()
		append_text(text)
		finish_tool_fold()
		return
	end
	append_message_header(role:gsub("^%l", string.upper))
	append_text(text)
end

local function send_extension_ui_response(id, response)
	response.type = "extension_ui_response"
	response.id = id
	send(response)
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
		pos_end = { 1, 1 },
	}
end

local function confirm_with_preview(event)
	local payload = decode_approval_payload(event.message)
	if not payload then
		return false
	end

	local prompt = payload.tool and ("Allow " .. payload.tool .. "?") or (event.title or "Pi confirm")
	local preview_item = approval_preview_item(payload)
	vim.ui.select({ "Allow", "Deny" }, {
		prompt = prompt,
		kind = "pi_approval",
		preview_item = function()
			return preview_item
		end,
	}, function(choice)
		send_extension_ui_response(event.id, { confirmed = choice == "Allow" })
	end)
	return true
end

local function update_access_mode_from_status(text)
	if type(text) ~= "string" then
		return
	end
	local mode = text:match("Mode:%s*(%w+)")
	if mode and is_access_mode(mode) then
		state.access_mode = mode
		refresh_transcript_ui()
	end
end

local function handle_extension_ui_request(event)
	if event.method == "set_editor_text" and type(event.text) == "string" and valid_buf(state.input_buf) then
		vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, vim.split(event.text, "\n", { plain = true }))
	elseif event.method == "notify" then
		notify(event.message or vim.inspect(event))
	elseif event.method == "setStatus" then
		if event.statusKey == "pi-access-mode" then
			update_access_mode_from_status(event.statusText)
		elseif event.statusKey == "pi-history-changed" then
			M.refresh_messages()
		elseif event.statusKey == "pi-session-title" then
			state.session_name = event.statusText
			refresh_transcript_ui()
		end
	elseif event.method == "setTitle" and type(event.title) == "string" then
		vim.opt.titlestring = event.title
		vim.opt.title = true
	elseif event.method == "select" then
		vim.ui.select(event.options or {}, { prompt = event.title or "Pi select" }, function(choice)
			if choice then
				send_extension_ui_response(event.id, { value = choice })
			else
				send_extension_ui_response(event.id, { cancelled = true })
			end
		end)
	elseif event.method == "confirm" then
		if confirm_with_preview(event) then
			return
		end
		local prompt = event.title or "Pi confirm"
		if type(event.message) == "string" and event.message ~= "" then
			prompt = prompt .. "\n" .. event.message
		end
		vim.ui.select({ "Yes", "No" }, { prompt = prompt }, function(choice)
			send_extension_ui_response(event.id, { confirmed = choice == "Yes" })
		end)
	elseif event.method == "input" then
		vim.ui.input({ prompt = event.title or "Pi input", default = event.placeholder or "" }, function(value)
			if value then
				send_extension_ui_response(event.id, { value = value })
			else
				send_extension_ui_response(event.id, { cancelled = true })
			end
		end)
	elseif event.method == "editor" then
		notify("Pi requested an editor UI, which pi-nvim does not support yet", vim.log.levels.WARN)
		send_extension_ui_response(event.id, { cancelled = true })
	end
end

local function handle_response(event)
	local callback = event.id and state.callbacks[event.id]
	if callback then
		state.callbacks[event.id] = nil
		callback(event)
		return
	end

	if event.success == false then
		render_error_message("Pi Error", event_error_text(event) or vim.inspect(event))
	end
end

local function handle_message_update(event)
	local update = event.assistantMessageEvent or {}

	if update.type == "text_start" then
		clear_assistant_placeholder()
		state.current_message_started = true
		append_message_header("Assistant")
	elseif update.type == "text_delta" then
		if not state.current_message_started then
			clear_assistant_placeholder()
			state.current_message_started = true
			append_message_header("Assistant")
		end
		append_text(update.delta or "")
	elseif update.type == "thinking_start" and M.config.show_thinking then
		clear_assistant_placeholder()
		append_lines({ "<details><summary>Thinking</summary>", "" })
	elseif update.type == "thinking_delta" and M.config.show_thinking then
		append_text(update.delta or "")
	elseif update.type == "thinking_end" and M.config.show_thinking then
		append_lines({ "</details>" })
	elseif update.type == "toolcall_start" then
		clear_assistant_placeholder()
		append_lines({ "### Tool Call", "" })
		start_tool_fold()
	elseif update.type == "toolcall_delta" then
		append_text(update.delta or "")
	elseif update.type == "toolcall_end" then
		finish_tool_fold()
		local tool = update.toolCall or {}
		append_status("Tool call ended: " .. (tool.name or tool.type or "tool"))
	elseif update.type == "error" then
		render_error_message("Agent Error", event_error_text(update) or "unknown")
	end
end

local function handle_event(event)
	if event.type == "response" then
		handle_response(event)
	elseif event.type == "agent_start" then
		state.is_streaming = true
		state.current_message_started = false
		state.error_rendered_for_active_run = false
		notify("Pi is working")
	elseif event.type == "agent_end" then
		state.is_streaming = false
		state.current_message_started = false
		local message = event_error_text(event)
		if message and not state.error_rendered_for_active_run then
			render_error_message("Agent Error", message)
		elseif assistant_placeholder_active() and state.abort_requested then
			clear_assistant_placeholder()
		elseif assistant_placeholder_active() and not state.error_rendered_for_active_run then
			render_error_message(
				"Agent Error",
				recent_stderr_text() or "Agent stopped before returning a message. No error details were provided."
			)
		else
			clear_assistant_placeholder()
		end
		state.abort_requested = false
		notify("Pi finished")
	elseif event.type == "message_update" then
		handle_message_update(event)
	elseif event.type == "message_end" and not state.current_message_started then
		if
			event.message
			and event.message.role == "user"
			and state.pending_user_message
			and vim.trim(extract_text(event.message) or "") == state.pending_user_message
		then
			state.pending_user_message = nil
			return
		end
		render_message(event.message)
	elseif event.type == "tool_execution_start" then
		clear_assistant_placeholder()
		local name = event.name or event.toolName or "started"
		append_lines({ "### Tool: " .. name, "" })
		start_tool_fold()
	elseif event.type == "tool_execution_update" then
		append_text(event.output or event.delta or event.text or "")
	elseif event.type == "tool_execution_end" then
		finish_tool_fold()
		append_status("Tool ended")
	elseif event.type == "queue_update" then
		local count = event.pendingMessageCount or event.count
		if count then
			notify("Pi queue: " .. tostring(count) .. " pending")
		end
	elseif event.type == "session_info_changed" then
		state.session_name = event.name
		refresh_transcript_ui()
	elseif event.type == "extension_ui_request" then
		handle_extension_ui_request(event)
	end
end

local function handle_jsonl_data(data, pending_key)
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
				local event = decode_json(chunk)
				if event then
					handle_event(event)
				end
			end
			state[pending_key] = ""
		else
			state[pending_key] = chunk
		end
	end
end

local function argv()
	local args = { M.config.binary, "--mode", "rpc" }
	if M.config.provider and M.config.provider ~= "" then
		vim.list_extend(args, { "--provider", M.config.provider })
	end
	if M.config.model and M.config.model ~= "" then
		vim.list_extend(args, { "--model", M.config.model })
	end
	if M.config.session_dir and M.config.session_dir ~= "" then
		vim.list_extend(args, { "--session-dir", vim.fn.expand(M.config.session_dir) })
	end
	return args
end

local function job_env()
	if M.config.agent_dir and M.config.agent_dir ~= "" then
		return { PI_CODING_AGENT_DIR = vim.fn.expand(M.config.agent_dir) }
	end
	return nil
end

local function create_buffer(name, filetype, modifiable)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, name)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", filetype, { buf = buf })
	vim.api.nvim_set_option_value("modifiable", modifiable, { buf = buf })
	return buf
end

local function set_buffer_lines(buf, lines, modifiable)
	set_modifiable(buf, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	set_modifiable(buf, modifiable)
end

local function apply_window_padding(win)
	vim.api.nvim_set_option_value("winbar", " ", { win = win })
	vim.api.nvim_set_option_value("statusline", "%#PiPaneBorder#%{repeat('─',winwidth(0))}%*", { win = win })
	vim.api.nvim_set_option_value("signcolumn", "yes:1", { win = win })
	vim.api.nvim_set_option_value("scrolloff", 1, { win = win })
	vim.api.nvim_set_option_value("sidescrolloff", 2, { win = win })
end

local function apply_transcript_window_options(win)
	apply_window_padding(win)
	vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
	vim.api.nvim_set_option_value("foldenable", true, { win = win })
	vim.api.nvim_set_option_value("foldlevel", 0, { win = win })
end

local function map_input(mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, { buffer = state.input_buf, desc = desc })
end

local function map_transcript(lhs, rhs, desc)
	vim.keymap.set("n", lhs, rhs, { buffer = state.transcript_buf, desc = desc })
end

local function setup_keymaps()
	map_input({ "n", "i" }, "<C-CR>", function()
		M.submit_prompt()
	end, "Submit prompt")
	map_input("n", "<Tab>", function()
		M.cycle_access_mode()
	end, "Cycle access mode")
	map_input("n", "<leader>?", function()
		M.show_help()
	end, "Pi help")
	map_input("n", "<leader>m", function()
		M.pick_model()
	end, "Pick model")
	map_input("n", "<leader>t", function()
		M.pick_thinking()
	end, "Pick thinking level")
	map_input("n", "<leader>p", function()
		M.pick_access_mode()
	end, "Pick access mode")
	map_input("n", "<leader>s", function()
		M.pick_session()
	end, "Pick session")
	map_input("n", "<leader>h", function()
		M.history()
	end, "History")
	map_input("n", "<leader>n", function()
		M.new_session()
	end, "New session")
	map_input("n", "<leader>r", function()
		M.refresh_messages()
	end, "Refresh transcript")
	map_input("n", "<leader>R", function()
		M.rename_session()
	end, "Rename session")

	map_transcript("<leader>m", function()
		M.pick_model()
	end, "Pick model")
	map_transcript("<Esc><Esc>", function()
		M.abort()
	end, "Abort Pi")
	map_transcript("<leader>t", function()
		M.pick_thinking()
	end, "Pick thinking level")
	map_transcript("<Tab>", function()
		M.cycle_access_mode()
	end, "Cycle access mode")
	map_transcript("<leader>?", function()
		M.show_help()
	end, "Pi help")
	map_transcript("<leader>p", function()
		M.pick_access_mode()
	end, "Pick access mode")
	map_transcript("<leader>s", function()
		M.pick_session()
	end, "Pick session")
	map_transcript("<leader>h", function()
		M.history()
	end, "History")
	map_transcript("<leader>n", function()
		M.new_session()
	end, "New session")
	map_transcript("<leader>r", function()
		M.refresh_messages()
	end, "Refresh transcript")
	map_transcript("<leader>R", function()
		M.rename_session()
	end, "Rename session")
	map_transcript("<CR>", function()
		if not toggle_tool_fold() then
			vim.cmd("normal! za")
		end
	end, "Toggle fold")
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	state.access_mode = "readonly"
	set_model_metadata(M.config.provider, M.config.model)
end

function M.open()
	if valid_buf(state.transcript_buf) and valid_buf(state.input_buf) then
		return
	end

	state.transcript_buf = create_buffer("pi://transcript", "markdown", false)
	state.input_buf = create_buffer("pi://input", "markdown", true)

	vim.api.nvim_win_set_buf(0, state.transcript_buf)
	state.transcript_win = vim.api.nvim_get_current_win()
	apply_transcript_window_options(state.transcript_win)
	vim.cmd("botright 12split")
	vim.api.nvim_win_set_buf(0, state.input_buf)
	state.input_win = vim.api.nvim_get_current_win()
	apply_window_padding(state.input_win)

	refresh_transcript_ui()

	setup_keymaps()
	M.start()
end

function M.start()
	if state.job and state.job > 0 then
		return
	end
	state.last_stderr_lines = {}
	state.error_rendered_for_active_run = false

	state.job = vim.fn.jobstart(argv(), {
		stdin = "pipe",
		env = job_env(),
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = function(_, data, _)
			vim.schedule(function()
				handle_jsonl_data(data, "stdout_pending")
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
					if M.config.show_stderr and line ~= "" then
						append_status("pi stderr: " .. line)
					end
				end
			end)
		end,
		on_exit = function(_, code, _)
			vim.schedule(function()
				if assistant_placeholder_active() and not state.error_rendered_for_active_run then
					render_error_message(
						"Pi Error",
						recent_stderr_text() or ("pi exited with code " .. tostring(code) .. " before returning a message")
					)
				else
					append_status("pi exited with code " .. tostring(code))
				end
				state.job = nil
				state.is_streaming = false
				state.abort_requested = false
			end)
		end,
	})

	if state.job <= 0 then
		notify("Failed to start pi. Is `pi` on PATH?", vim.log.levels.ERROR)
		state.job = nil
		return
	end

	send({ type = "get_state" }, function(event)
		if event.success and event.data then
			apply_session_state(event.data)
		end
	end)
end

function M.submit_prompt()
	local text = get_input()
	if text == "" then
		return
	end
	state.abort_requested = false
	state.error_rendered_for_active_run = false
	clear_input()
	state.pending_user_message = text
	append_message_header("You")
	append_text(text)

	local cmd = { type = "prompt", message = text }
	if state.is_streaming then
		cmd.streamingBehavior = "steer"
	elseif not text:match("^%s*/") then
		start_assistant_placeholder()
	end
	send(cmd)
end

function M.abort()
	state.abort_requested = true
	send({ type = "abort" })
end

function M.history()
	send({ type = "prompt", message = "/pi-history" }, function(event)
		if not event.success then
			notify(event.error or "Could not open history", vim.log.levels.ERROR)
		end
	end)
end

function M.rename_session()
	send({ type = "prompt", message = "/pi-rename" }, function(event)
		if not event.success then
			notify(event.error or "Could not rename session", vim.log.levels.ERROR)
		end
	end)
end

function M.new_session()
	send({ type = "new_session" }, function(event)
		if event.success then
			set_modifiable(state.transcript_buf, true)
			vim.api.nvim_buf_set_lines(state.transcript_buf, 0, -1, false, {})
			set_modifiable(state.transcript_buf, false)
			delete_tool_folds()
			state.session_name = nil
			state.message_count = 0
			refresh_transcript_ui()
			append_status("New session.")
			send({ type = "get_state" }, function(state_event)
				if state_event.success and state_event.data then
					apply_session_state(state_event.data)
				end
			end)
		end
	end)
end

function M.refresh_messages()
	send({ type = "get_messages" }, function(event)
		if not event.success or not event.data then
			notify("Could not get messages", vim.log.levels.ERROR)
			return
		end

		set_modifiable(state.transcript_buf, true)
		vim.api.nvim_buf_set_lines(state.transcript_buf, 0, -1, false, {})
		set_modifiable(state.transcript_buf, false)
		delete_tool_folds()
		refresh_transcript_ui()

		for _, message in ipairs(event.data.messages or {}) do
			render_message(message)
		end
	end)
end

function M.set_access_mode(mode)
	assert(is_access_mode(mode), "invalid access mode: " .. tostring(mode))
	state.access_mode = mode
	refresh_transcript_ui()
	send({ type = "prompt", message = "/pi-mode " .. mode }, function(event)
		if not event.success then
			notify(event.error or "Could not set access mode", vim.log.levels.ERROR)
		end
	end)
end

function M.pick_access_mode()
	vim.ui.select(M.config.access_modes or {}, { prompt = "Pi access mode" }, function(choice)
		if not choice then
			return
		end
		M.set_access_mode(choice)
	end)
end

function M.cycle_access_mode()
	local modes = M.config.access_modes or {}
	if #modes == 0 then
		return
	end

	local current = 1
	for index, mode in ipairs(modes) do
		if mode == state.access_mode then
			current = index
			break
		end
	end

	local next_index = current + 1
	if next_index > #modes then
		next_index = 1
	end
	M.set_access_mode(modes[next_index])
end

function M.show_help()
	if state.help_win and vim.api.nvim_win_is_valid(state.help_win) then
		vim.api.nvim_win_close(state.help_win, true)
		state.help_win = nil
		return
	end

	if not valid_buf(state.help_buf) then
		state.help_buf = create_buffer("pi://help", "markdown", false)
	end

	local lines = {
		"# Pi Help",
		"",
		"## Keys",
		"",
		"- `<C-CR>` submit the input buffer.",
		"- `<Tab>` cycle access mode: readonly -> write.",
		"- `<leader>p` pick access mode.",
		"- `<leader>m` pick model.",
		"- `<leader>t` pick thinking level.",
		"- `<leader>s` pick session.",
		"- `<leader>h` pick a previous user message to fork or revert.",
		"- `<leader>n` new session.",
		"- `<leader>r` refresh transcript.",
		"- `<leader>R` rename session.",
		"- `<CR>` toggle the current tool output fold.",
		"- `<C-c>` abort PI.",
		"- `q` or `<Esc>` close this help.",
		"",
		"## Access Modes",
		"",
		"- `readonly`: allow listed read-only bash commands; ask before other bash, edit, or write tools.",
		"- `write`: allow available tools.",
		"",
		"## Streaming",
		"",
		"When a run is already streaming, submitting another prompt is sent as PI steering for the active run.",
	}
	set_buffer_lines(state.help_buf, lines, false)

	local width = math.min(72, math.max(48, math.floor(vim.o.columns * 0.55)))
	local height = math.min(#lines + 2, math.max(14, math.floor(vim.o.lines * 0.65)))
	local row = math.max(1, math.floor((vim.o.lines - height) / 2))
	local col = math.max(0, math.floor((vim.o.columns - width) / 2))

	state.help_win = vim.api.nvim_open_win(state.help_buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Pi Help ",
		title_pos = "center",
	})

	vim.keymap.set("n", "q", function()
		M.show_help()
	end, { buffer = state.help_buf, desc = "Close help" })
	vim.keymap.set("n", "<Esc>", function()
		M.show_help()
	end, { buffer = state.help_buf, desc = "Close help" })
end

function M.pick_thinking()
	local levels = { "off", "minimal", "low", "medium", "high", "xhigh" }
	vim.ui.select(levels, { prompt = "Thinking level" }, function(choice)
		if not choice then
			return
		end
		send({ type = "set_thinking_level", level = choice }, function(event)
			if event.success then
				notify("Thinking: " .. choice)
			else
				notify("Could not set thinking level", vim.log.levels.ERROR)
			end
		end)
	end)
end

function M.pick_model()
	send({ type = "get_available_models" }, function(event)
		local models = event.data and event.data.models or {}
		if #models == 0 then
			notify("No models returned by Pi", vim.log.levels.WARN)
			return
		end

		vim.ui.select(models, {
			prompt = "Pi model",
			format_item = model_label,
		}, function(choice)
			if not choice then
				return
			end
			local provider, model_id = model_parts(choice)
			if not provider or not model_id then
				notify("Could not infer provider/modelId from selected model", vim.log.levels.ERROR)
				return
			end
			send({ type = "set_model", provider = provider, modelId = model_id }, function(set_event)
				if set_event.success then
					M.config.provider = provider
					M.config.model = model_id
					set_model_metadata(provider, model_id)
					refresh_transcript_ui()
					notify("Model: " .. model_label(choice))
				else
					notify("Could not set model", vim.log.levels.ERROR)
				end
			end)
		end)
	end)
end

local function dirname(path)
	if not path or path == "" then
		return nil
	end
	return vim.fn.fnamemodify(path, ":h")
end

local function session_candidates()
	local dirs = {}
	local seen_dirs = {}
	local function add_dir(path)
		if not path or path == "" then
			return
		end
		path = vim.fn.expand(path)
		if vim.fn.isdirectory(path) == 1 and not seen_dirs[path] then
			seen_dirs[path] = true
			table.insert(dirs, path)
		end
	end

	add_dir(M.config.session_dir)
	if M.config.agent_dir and M.config.agent_dir ~= "" then
		add_dir(vim.fn.expand(M.config.agent_dir) .. "/sessions")
	end
	add_dir(dirname(state.session_file))
	for _, dir in ipairs(M.config.session_dirs or {}) do
		add_dir(dir)
	end

	local files = {}
	local seen_files = {}
	for _, dir in ipairs(dirs) do
		for _, path in ipairs(vim.fn.globpath(dir, "**/*.jsonl", false, true)) do
			if not seen_files[path] then
				seen_files[path] = true
				table.insert(files, path)
			end
		end
	end

	table.sort(files, function(a, b)
		return vim.fn.getftime(a) > vim.fn.getftime(b)
	end)
	return files
end

local function session_label(path)
	local name = vim.fn.fnamemodify(path, ":t")
	local parent = vim.fn.fnamemodify(vim.fn.fnamemodify(path, ":h"), ":t")
	local time = os.date("%Y-%m-%d %H:%M", vim.fn.getftime(path))
	return string.format("%s/%s  %s", parent, name, time)
end

function M.pick_session()
	local files = session_candidates()
	if #files == 0 then
		notify("No session files found. Set PI_SESSION_DIR if your Pi sessions live elsewhere.", vim.log.levels.WARN)
		return
	end

	vim.ui.select(files, {
		prompt = "Pi session",
		format_item = session_label,
	}, function(choice)
		if not choice then
			return
		end
		send({ type = "switch_session", sessionPath = choice }, function(event)
			if event.success and not (event.data and event.data.cancelled) then
				state.session_file = choice
				send({ type = "get_state" }, function(state_event)
					if state_event.success and state_event.data then
						apply_session_state(state_event.data)
					end
				end)
				M.refresh_messages()
				notify("Switched session")
			else
				notify("Session switch cancelled or failed", vim.log.levels.ERROR)
			end
		end)
	end)
end

vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		if state.job and state.job > 0 then
			vim.fn.jobstop(state.job)
		end
	end,
})

return M

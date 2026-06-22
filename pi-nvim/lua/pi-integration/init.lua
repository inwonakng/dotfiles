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
	is_streaming = false,
	mode = "build",
	mode_prefix = "",
	current_message_started = false,
	session_file = nil,
}

M.config = {
	binary = "pi",
	provider = nil,
	model = nil,
	session_dir = nil,
	show_thinking = false,
	modes = {
		build = "",
		ask = "You are in ask mode. Explain and reason, but do not make file edits or run mutating commands unless I explicitly ask.",
		plan = "You are in plan mode. Inspect and think carefully. Produce a concrete plan, risks, and verification steps. Do not implement yet unless I explicitly say to proceed.",
		review = "You are in review mode. Prioritize bugs, regressions, missing tests, and risky behavior. Put findings first, ordered by severity.",
	},
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

local function append_lines(lines)
	if not valid_buf(state.transcript_buf) then
		return
	end
	if type(lines) == "string" then
		lines = vim.split(lines, "\n", { plain = true })
	end
	set_modifiable(state.transcript_buf, true)
	local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
	if line_count == 1 and vim.api.nvim_buf_get_lines(state.transcript_buf, 0, 1, false)[1] == "" then
		vim.api.nvim_buf_set_lines(state.transcript_buf, 0, 1, false, lines)
	else
		vim.api.nvim_buf_set_lines(state.transcript_buf, line_count, line_count, false, lines)
	end
	set_modifiable(state.transcript_buf, false)
	if state.transcript_win and vim.api.nvim_win_is_valid(state.transcript_win) then
		vim.api.nvim_win_set_cursor(state.transcript_win, { vim.api.nvim_buf_line_count(state.transcript_buf), 0 })
	end
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
	append_lines({ "", "```text", "Bad JSON from pi: " .. line, "```" })
	return nil
end

local function next_request_id()
	state.next_id = state.next_id + 1
	return "pi-nvim-" .. tostring(state.next_id)
end

local function send(cmd, callback)
	M.start()

	if callback then
		cmd.id = cmd.id or next_request_id()
		state.callbacks[cmd.id] = callback
	end

	local line = encode_json(cmd) .. "\n"
	vim.fn.chansend(state.job, line)
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

local function with_mode_prefix(text)
	if state.mode_prefix == nil or state.mode_prefix == "" then
		return text
	end
	return state.mode_prefix .. "\n\n" .. text
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
	append_lines({ "", "## " .. role:gsub("^%l", string.upper), "" })
	append_text(text)
	append_lines({ "" })
end

local function handle_response(event)
	local callback = event.id and state.callbacks[event.id]
	if callback then
		state.callbacks[event.id] = nil
		callback(event)
		return
	end

	if event.success == false then
		append_lines({ "", "## Pi Error", "", "```text", event.error or event.message or vim.inspect(event), "```" })
	end
end

local function handle_message_update(event)
	local update = event.assistantMessageEvent or {}

	if update.type == "text_start" then
		state.current_message_started = true
		append_lines({ "", "## Assistant", "" })
	elseif update.type == "text_delta" then
		if not state.current_message_started then
			state.current_message_started = true
			append_lines({ "", "## Assistant", "" })
		end
		append_text(update.delta or "")
	elseif update.type == "thinking_start" and M.config.show_thinking then
		append_lines({ "", "<details><summary>Thinking</summary>", "" })
	elseif update.type == "thinking_delta" and M.config.show_thinking then
		append_text(update.delta or "")
	elseif update.type == "thinking_end" and M.config.show_thinking then
		append_lines({ "", "</details>", "" })
	elseif update.type == "toolcall_start" then
		append_lines({ "", "```text", "tool call started" })
	elseif update.type == "toolcall_delta" then
		append_text(update.delta or "")
	elseif update.type == "toolcall_end" then
		local tool = update.toolCall or {}
		append_lines({ "tool call ended: " .. (tool.name or tool.type or "tool"), "```" })
	elseif update.type == "error" then
		append_lines({ "", "```text", "agent error: " .. (update.reason or "unknown"), "```" })
	end
end

local function handle_event(event)
	if event.type == "response" then
		handle_response(event)
	elseif event.type == "agent_start" then
		state.is_streaming = true
		state.current_message_started = false
		notify("Pi is working")
	elseif event.type == "agent_end" then
		state.is_streaming = false
		state.current_message_started = false
		append_lines({ "" })
		notify("Pi finished")
	elseif event.type == "message_update" then
		handle_message_update(event)
	elseif event.type == "message_end" and not state.current_message_started then
		render_message(event.message)
	elseif event.type == "tool_execution_start" then
		append_lines({ "", "```text", "tool: " .. (event.name or event.toolName or "started") })
	elseif event.type == "tool_execution_update" then
		append_text(event.output or event.delta or event.text or "")
	elseif event.type == "tool_execution_end" then
		append_lines({ "tool ended", "```" })
	elseif event.type == "queue_update" then
		local count = event.pendingMessageCount or event.count
		if count then
			notify("Pi queue: " .. tostring(count) .. " pending")
		end
	elseif event.type == "extension_ui_request" then
		if event.method == "set_editor_text" and type(event.text) == "string" and valid_buf(state.input_buf) then
			vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, vim.split(event.text, "\n", { plain = true }))
		elseif event.method == "notify" then
			notify(event.message or vim.inspect(event))
		end
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

local function map_input(lhs, rhs, desc)
	vim.keymap.set({ "n", "i" }, lhs, rhs, { buffer = state.input_buf, desc = desc })
end

local function map_transcript(lhs, rhs, desc)
	vim.keymap.set("n", lhs, rhs, { buffer = state.transcript_buf, desc = desc })
end

local function setup_keymaps()
	map_input("<C-s>", function()
		M.submit_prompt()
	end, "Submit prompt")
	map_input("<M-s>", function()
		M.submit_steer()
	end, "Steer current run")
	map_input("<M-f>", function()
		M.submit_follow_up()
	end, "Queue follow-up")
	map_input("<C-c>", function()
		M.abort()
	end, "Abort Pi")
	map_input("<leader>m", function()
		M.pick_model()
	end, "Pick model")
	map_input("<leader>t", function()
		M.pick_thinking()
	end, "Pick thinking level")
	map_input("<leader>p", function()
		M.pick_mode()
	end, "Pick Pi UI mode")
	map_input("<leader>s", function()
		M.pick_session()
	end, "Pick session")
	map_input("<leader>n", function()
		M.new_session()
	end, "New session")
	map_input("<leader>r", function()
		M.refresh_messages()
	end, "Refresh transcript")

	map_transcript("<leader>m", function()
		M.pick_model()
	end, "Pick model")
	map_transcript("<leader>t", function()
		M.pick_thinking()
	end, "Pick thinking level")
	map_transcript("<leader>p", function()
		M.pick_mode()
	end, "Pick Pi UI mode")
	map_transcript("<leader>s", function()
		M.pick_session()
	end, "Pick session")
	map_transcript("<leader>n", function()
		M.new_session()
	end, "New session")
	map_transcript("<leader>r", function()
		M.refresh_messages()
	end, "Refresh transcript")
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	state.mode = "build"
	state.mode_prefix = M.config.modes.build or ""
end

function M.open()
	if valid_buf(state.transcript_buf) and valid_buf(state.input_buf) then
		return
	end

	state.transcript_buf = create_buffer("pi://transcript", "markdown", false)
	state.input_buf = create_buffer("pi://input", "markdown", true)

	vim.api.nvim_win_set_buf(0, state.transcript_buf)
	state.transcript_win = vim.api.nvim_get_current_win()
	vim.cmd("botright 12split")
	vim.api.nvim_win_set_buf(0, state.input_buf)
	state.input_win = vim.api.nvim_get_current_win()

	append_lines({
		"# Pi",
		"",
		"Write in the input buffer below.",
		"",
		"- `<C-s>` submit",
		"- `<M-s>` steer current run",
		"- `<M-f>` queue follow-up",
		"- `<C-c>` abort",
		"- `<leader>m` model, `<leader>t` thinking, `<leader>p` mode, `<leader>s` session",
		"",
	})

	setup_keymaps()
	M.start()
end

function M.start()
	if state.job and state.job > 0 then
		return
	end

	state.job = vim.fn.jobstart(argv(), {
		stdin = "pipe",
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
						append_lines({ "", "```text", "pi stderr: " .. line, "```" })
					end
				end
			end)
		end,
		on_exit = function(_, code, _)
			vim.schedule(function()
				append_lines({ "", "```text", "pi exited with code " .. tostring(code), "```" })
				state.job = nil
				state.is_streaming = false
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
			state.session_file = event.data.sessionFile
			state.is_streaming = event.data.isStreaming or false
		end
	end)
end

function M.submit_prompt()
	local text = get_input()
	if text == "" then
		return
	end
	clear_input()
	append_lines({ "", "## You", "" })
	append_text(text)
	append_lines({ "" })

	local cmd = { type = "prompt", message = with_mode_prefix(text) }
	if state.is_streaming then
		cmd.streamingBehavior = "steer"
	end
	send(cmd)
end

function M.submit_steer()
	local text = get_input()
	if text == "" then
		return
	end
	clear_input()
	append_lines({ "", "## You (steer)", "" })
	append_text(text)
	append_lines({ "" })
	send({ type = "steer", message = with_mode_prefix(text) })
end

function M.submit_follow_up()
	local text = get_input()
	if text == "" then
		return
	end
	clear_input()
	append_lines({ "", "## You (follow-up)", "" })
	append_text(text)
	append_lines({ "" })
	send({ type = "follow_up", message = with_mode_prefix(text) })
end

function M.abort()
	send({ type = "abort" })
end

function M.new_session()
	send({ type = "new_session" }, function(event)
		if event.success then
			set_modifiable(state.transcript_buf, true)
			vim.api.nvim_buf_set_lines(state.transcript_buf, 0, -1, false, { "# Pi", "", "New session.", "" })
			set_modifiable(state.transcript_buf, false)
			send({ type = "get_state" }, function(state_event)
				if state_event.success and state_event.data then
					state.session_file = state_event.data.sessionFile
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
		vim.api.nvim_buf_set_lines(state.transcript_buf, 0, -1, false, { "# Pi", "" })
		set_modifiable(state.transcript_buf, false)

		for _, message in ipairs(event.data.messages or {}) do
			render_message(message)
		end
	end)
end

function M.pick_mode()
	local names = vim.tbl_keys(M.config.modes)
	table.sort(names)
	vim.ui.select(names, { prompt = "Pi mode" }, function(choice)
		if not choice then
			return
		end
		state.mode = choice
		state.mode_prefix = M.config.modes[choice] or ""
		notify("Mode: " .. choice)
	end)
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

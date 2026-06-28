local M = {}

local INITIAL_SESSION_NOTICE = "No Pi session started yet. Send a message or pick a session."
local NEW_SESSION_NOTICE = "New session."
local PENDING_NEW_SESSION_NOTICE = "New session will be created when you send a message."

local state = require("pi-integration.state").new()

M.config = {
	binary = "pi",
	agent_dir = nil,
	provider = nil,
	model = nil,
	session_dir = nil,
	show_thinking = true,
	show_stderr = false,
	access_modes = { "readonly", "write" },
	session_dirs = {
		"~/.pi/agent/sessions",
		"~/.pi/sessions",
	},
	tree_entry_types = {
		message = true,
		branch_summary = true,
		compaction = true,
		bashExecution = true,
		custom_message = true,
		model_change = true,
		thinking_level_change = true,
		label = true,
	},
	tree_filter_modes = { "default", "no-tools", "user-only", "all" },
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

local pi_transcript
local pi_rpc
local pi_events
local pi_layout
local pi_actions
local integration_ctx
local setup_keymaps
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

local update_transcript_statusline

local function transcript_ctx()
	return {
		state = state,
		config = M.config,
		valid_buf = valid_buf,
		set_modifiable = set_modifiable,
		update_transcript_statusline = update_transcript_statusline,
	}
end

local function metadata_lines()
	return pi_transcript.metadata_lines(transcript_ctx())
end

local function render_transcript()
	return pi_transcript.render(transcript_ctx())
end

local function refresh_transcript_ui()
	return pi_transcript.refresh_ui(transcript_ctx())
end

local function apply_session_state(data)
	if data.sessionFile ~= state.session_file then
		state.tree_leaf_id = nil
	end
	state.session_file = data.sessionFile
	state.session_name = data.sessionName
	state.message_count = data.messageCount or state.message_count
	state.is_streaming = data.isStreaming or false
	state.thinking_level = data.thinkingLevel or data.thinking_level or state.thinking_level
	set_model_metadata(data.provider or data.providerId or data.providerName, data.model or data.modelId)
	refresh_transcript_ui()
end

local function transcript_line_count()
	return pi_transcript.line_count(transcript_ctx())
end

local function update_transcript_bottom_padding()
	return pi_transcript.update_bottom_padding(transcript_ctx())
end

local function transcript_win_valid()
	return pi_transcript.win_valid(transcript_ctx())
end

local function clear_transcript_items()
	return pi_transcript.clear_transcript_items(transcript_ctx())
end

local function append_lines(lines)
	return pi_transcript.append_lines(transcript_ctx(), lines)
end

local function append_text(text)
	return pi_transcript.append_text(transcript_ctx(), text)
end

local function append_message_header(role)
	return pi_transcript.append_message_header(transcript_ctx(), role)
end

local function append_status(text)
	return pi_transcript.append_status(transcript_ctx(), text)
end

local pi_tool_output = require("pi-integration.tool-output")
local pi_thinking_output = require("pi-integration.thinking-output")
local pi_skills = require("pi-integration.skills")
local pi_pickers

local function tool_output_ctx()
	return {
		state = state,
		notify = notify,
	}
end

local function reset_transcript_outputs()
	pi_tool_output.reset(state)
	pi_thinking_output.reset(state)
	pi_skills.reset(state)
end

local function store_tool_output(tool_name, text, filetype, details)
	return pi_tool_output.store(state, tool_name, text, filetype, details)
end

local function tool_output_summary_lines(output_id)
	return pi_tool_output.summary_lines(state, output_id)
end

local function store_thinking_output(text)
	return pi_thinking_output.store(state, text)
end

local function append_thinking_output(output_id, delta)
	return pi_thinking_output.append(state, output_id, delta)
end

local function thinking_output_text(output_id)
	return pi_thinking_output.text(state, output_id)
end

local function thinking_output_summary_lines(output_id, streaming)
	return pi_thinking_output.summary_lines(state, output_id, streaming)
end

local function begin_trace_item()
	return pi_transcript.begin_trace_item(transcript_ctx())
end

local function remove_status(text)
	return pi_transcript.remove_status(transcript_ctx(), text)
end

local function end_trace_item()
	return pi_transcript.end_trace_item(transcript_ctx())
end

local function register_transcript_item(item)
	return pi_transcript.register_transcript_item(transcript_ctx(), item)
end

local function set_transcript_line(line, text)
	return pi_transcript.set_line(transcript_ctx(), line, text)
end

local function open_transcript_item_under_cursor()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local item = pi_transcript.transcript_item_at_line(transcript_ctx(), cursor[1])
	if not item then
		return false
	end
	if item.kind == "tool" then
		return pi_tool_output.open_float(tool_output_ctx(), item.output_id)
	elseif item.kind == "thinking" then
		return pi_thinking_output.open_float(tool_output_ctx(), item.output_id)
	end
	return false
end

local function clear_assistant_placeholder()
	return pi_transcript.clear_assistant_placeholder(transcript_ctx())
end

local function clear_assistant_placeholder_spinner()
	return pi_transcript.clear_assistant_placeholder_spinner(transcript_ctx())
end

local function start_assistant_placeholder()
	return pi_transcript.start_assistant_placeholder(transcript_ctx())
end

local function assistant_placeholder_active()
	return pi_transcript.assistant_placeholder_active(transcript_ctx())
end

local function render_error_message(title, message)
	return pi_transcript.render_error_message(transcript_ctx(), title, message)
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

local function send(cmd, callback)
	return pi_rpc.send(integration_ctx(), cmd, callback)
end

local function set_input_text(text)
	if not valid_buf(state.input_buf) then
		return
	end
	vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, vim.split(text or "", "\n", { plain = true }))
	if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
		vim.api.nvim_set_current_win(state.input_win)
		vim.api.nvim_win_set_cursor(state.input_win, { vim.api.nvim_buf_line_count(state.input_buf), 0 })
	end
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

local function handle_response(event)
	return pi_rpc.handle_response(integration_ctx(), event)
end

local function handle_event(event)
	return pi_events.handle_event(integration_ctx(), event)
end

local function create_buffer(name, filetype, modifiable)
	return pi_layout.create_buffer(integration_ctx(), name, filetype, modifiable)
end

local function set_buffer_lines(buf, lines, modifiable)
	return pi_layout.set_buffer_lines(integration_ctx(), buf, lines, modifiable)
end

local load_session_messages_from_file
local render_messages

local pi_keymaps = require("pi-integration.keymaps")
local pi_help = require("pi-integration.help")
local pi_statusline = require("pi-integration.statusline")
local pi_tree = require("pi-integration.tree")
local pi_sessions = require("pi-integration.sessions")
local pi_messages = require("pi-integration.messages")
pi_transcript = require("pi-integration.transcript")
pi_rpc = require("pi-integration.rpc")
pi_events = require("pi-integration.events")
pi_layout = require("pi-integration.layout")
pi_actions = require("pi-integration.actions")
pi_pickers = require("pi-integration.pickers")

integration_ctx = function()
	return {
		state = state,
		config = M.config,
		actions = M,
		notify = notify,

		-- Generic helpers.
		valid_buf = valid_buf,
		set_modifiable = set_modifiable,
		create_buffer = create_buffer,
		set_buffer_lines = set_buffer_lines,
		extract_text = extract_text,
		send = send,

		-- Transcript helpers.
		transcript_win_valid = transcript_win_valid,
		metadata_lines = metadata_lines,
		refresh_transcript_ui = refresh_transcript_ui,
		update_transcript_statusline = update_transcript_statusline,
		append_status = append_status,
		append_lines = append_lines,
		append_text = append_text,
		append_message_header = append_message_header,
		remove_status = remove_status,
		transcript_line_count = transcript_line_count,
		clear_transcript_items = clear_transcript_items,
		begin_trace_item = begin_trace_item,
		end_trace_item = end_trace_item,
		start_assistant_placeholder = start_assistant_placeholder,
		assistant_placeholder_active = assistant_placeholder_active,
		clear_assistant_placeholder = clear_assistant_placeholder,
		clear_assistant_placeholder_spinner = clear_assistant_placeholder_spinner,
		render_error_message = render_error_message,

		-- RPC/event helpers.
		handle_event = handle_event,
		handle_response = handle_response,
		event_error_text = event_error_text,
		recent_stderr_text = recent_stderr_text,

		-- Feature helpers.
		set_model_metadata = set_model_metadata,
		set_input_text = set_input_text,
		store_tool_output = store_tool_output,
		tool_output_summary_lines = tool_output_summary_lines,
		store_thinking_output = store_thinking_output,
		append_thinking_output = append_thinking_output,
		thinking_output_text = thinking_output_text,
		thinking_output_summary_lines = thinking_output_summary_lines,
		register_transcript_item = register_transcript_item,
		set_transcript_line = set_transcript_line,
		apply_session_state = apply_session_state,
		load_session_messages_from_file = load_session_messages_from_file,
		render_messages = render_messages,
		open_transcript_item_under_cursor = open_transcript_item_under_cursor,
		setup_keymaps = setup_keymaps,
		is_access_mode = function(mode)
			return pi_pickers.is_access_mode({ config = M.config }, mode)
		end,

		-- User-facing notices.
		initial_session_notice = INITIAL_SESSION_NOTICE,
		new_session_notice = NEW_SESSION_NOTICE,
		pending_new_session_notice = PENDING_NEW_SESSION_NOTICE,
	}
end

setup_keymaps = function()
	pi_keymaps.setup(integration_ctx())
end

update_transcript_statusline = function()
	pi_statusline.update(integration_ctx())
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	state.access_mode = "readonly"
	set_model_metadata(M.config.provider, M.config.model)
	pi_statusline.setup(integration_ctx())
end

function M.open()
	pi_layout.open(integration_ctx())
end

function M.show_input()
	pi_layout.show_input(integration_ctx())
end

function M.show_transcript()
	local recreated = pi_layout.show_transcript(integration_ctx())
	if state.session_file or state.pending_session_file or (state.job and state.job > 0) then
		M.refresh_messages()
	elseif recreated then
		append_status(INITIAL_SESSION_NOTICE)
	end
end

function M.start()
	pi_rpc.start(integration_ctx())
end

function M.refresh_session_stats()
	pi_actions.refresh_session_stats(integration_ctx())
end

function M.submit_prompt()
	pi_actions.submit_prompt(integration_ctx())
end

function M.abort()
	pi_actions.abort(integration_ctx())
end

function M.history()
	pi_actions.history(integration_ctx())
end

function M.toggle_notifications()
	pi_actions.toggle_notifications(integration_ctx())
end

function M.rename_session()
	pi_actions.rename_session(integration_ctx())
end

function M.new_session()
	pi_actions.new_session(integration_ctx())
end

load_session_messages_from_file = function(path)
	return pi_messages.load_session_messages_from_file(integration_ctx(), path)
end

local function collect_message_lines(messages)
	return pi_messages.collect_message_lines(integration_ctx(), messages)
end

local function apply_collected_transcript_items(items)
	return pi_transcript.apply_collected_transcript_items(transcript_ctx(), items)
end

local function scroll_transcript_to_bottom()
	return pi_transcript.scroll_to_bottom(transcript_ctx())
end

render_messages = function(messages)
	if not valid_buf(state.transcript_buf) then
		return
	end

	state.last_updated = os.date("%Y-%m-%d %H:%M:%S %z")
	reset_transcript_outputs()
	local lines, items = collect_message_lines(messages)
	set_buffer_lines(state.transcript_buf, lines, false)
	apply_collected_transcript_items(items)
	update_transcript_bottom_padding()
	update_transcript_statusline()
	render_transcript()
	scroll_transcript_to_bottom()
	vim.schedule(scroll_transcript_to_bottom)
end

function M.refresh_messages()
	if not (state.job and state.job > 0) then
		local path = state.pending_session_file or state.session_file
		if path and path ~= "" then
			render_messages(load_session_messages_from_file(path))
		else
			notify("No Pi session has been started yet.", vim.log.levels.WARN)
		end
		return
	end

	send({ type = "get_messages" }, function(event)
		if not event.success or not event.data then
			notify("Could not get messages", vim.log.levels.ERROR)
			return
		end

		render_messages(event.data.messages or {})
		M.refresh_session_stats()
	end)
end

function M.show_tree()
	pi_tree.show(integration_ctx())
end

function M.set_access_mode(mode)
	pi_pickers.set_access_mode(integration_ctx(), mode)
end

function M.pick_access_mode()
	pi_pickers.pick_access_mode(integration_ctx())
end

function M.cycle_access_mode()
	pi_pickers.cycle_access_mode(integration_ctx())
end

function M.show_help()
	pi_help.toggle(integration_ctx())
end

function M.pick_thinking()
	pi_pickers.pick_thinking(integration_ctx())
end

function M.pick_model()
	pi_pickers.pick_model(integration_ctx())
end

function M.pick_command()
	pi_pickers.pick_command(integration_ctx())
end

function M.get_commands(callback)
	send({ type = "get_commands" }, function(event)
		local commands = event.success and event.data and event.data.commands or {}
		callback(commands)
	end)
end

function M.reload()
	pi_pickers.reload(integration_ctx())
end

function M.pick_session()
	pi_sessions.pick(integration_ctx())
end
vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		pi_rpc.stop(integration_ctx())
	end,
})

return M

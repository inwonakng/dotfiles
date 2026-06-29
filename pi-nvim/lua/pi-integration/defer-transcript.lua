local floats = require("pi-integration.floats")
local pi_messages = require("pi-integration.messages")
local pi_tool_output = require("pi-integration.tool-output")
local pi_thinking_output = require("pi-integration.thinking-output")
local pi_skills = require("pi-integration.skills")
local pi_transcript = require("pi-integration.transcript")

local M = {}

local function decode_json(line)
	local ok, decoded
	if vim.json and vim.json.decode then
		ok, decoded = pcall(vim.json.decode, line)
	else
		ok, decoded = pcall(vim.fn.json_decode, line)
	end
	if ok and type(decoded) == "table" then
		return decoded
	end
	return nil
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

local function read_messages(path)
	local messages = {}
	if not path or vim.fn.filereadable(path) ~= 1 then
		return messages
	end
	for _, line in ipairs(vim.fn.readfile(path)) do
		local record = decode_json(line)
		local event = type(record) == "table" and record.event or nil
		if type(event) == "table" and event.type == "message_end" and type(event.message) == "table" then
			table.insert(messages, event.message)
		end
	end
	return messages
end

local function valid_buf(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

local function set_modifiable(buf, value)
	if valid_buf(buf) then
		vim.api.nvim_set_option_value("modifiable", value, { buf = buf })
	end
end

local function metadata_lines(path)
	return {
		"---",
		"title: \"Defer transcript\"",
		"source: \"" .. tostring(path):gsub("\\", "\\\\"):gsub('"', '\\"') .. "\"",
		"last_updated: \"" .. os.date("%Y-%m-%d %H:%M:%S %z") .. "\"",
		"---",
	}
end

local function make_render_ctx(state, path)
	return {
		state = state,
		metadata_lines = function()
			return metadata_lines(path)
		end,
		extract_text = extract_text,
		record_tool_calls = function(message)
			return pi_tool_output.record_calls(state, message)
		end,
		record_tool_execution_call = function(tool_name, tool_call_id, args)
			return pi_tool_output.record_execution_call(state, tool_name, tool_call_id, args)
		end,
		store_tool_output = function(tool_name, text, filetype, details, message)
			local tool_call_id = message and (message.toolCallId or message.tool_call_id or message.id)
			return pi_tool_output.store(state, tool_name, text, filetype, details, pi_tool_output.display_for_result(state, message), tool_call_id)
		end,
		tool_output_summary_lines = function(output_id)
			return pi_tool_output.summary_lines(state, output_id)
		end,
		store_thinking_output = function(text)
			return pi_thinking_output.store(state, text)
		end,
		thinking_output_summary_lines = function(output_id, streaming)
			return pi_thinking_output.summary_lines(state, output_id, streaming)
		end,
		store_skill_prompt = function(load)
			return pi_skills.store_load(state, load)
		end,
		skill_summary_lines = function(output_id)
			return pi_skills.summary_lines(state, output_id)
		end,
		apply_skill_tool_result = function(message)
			return pi_skills.apply_tool_result(state, message, extract_text(message))
		end,
	}
end

local function render_lines(path, state)
	state.transcript_items = {}
	pi_tool_output.reset(state)
	pi_thinking_output.reset(state)
	pi_skills.reset(state)
	local lines, items = pi_messages.collect_message_lines(make_render_ctx(state, path), read_messages(path))
	state.transcript_items = items or {}
	return lines
end

local function transcript_ctx(state)
	return {
		state = state,
		valid_buf = valid_buf,
		set_modifiable = set_modifiable,
		update_transcript_statusline = function() end,
	}
end

local function render_transcript_ui(state)
	pi_transcript.update_bottom_padding(transcript_ctx(state))
	pi_transcript.render(transcript_ctx(state))
end

local function item_at_line(state, line)
	for _, item in ipairs(state.transcript_items or {}) do
		local start_line = item.start_line or item.line
		local end_line = item.end_line or start_line
		if start_line and end_line and line >= start_line and line <= end_line then
			return item
		end
	end
	return nil
end

local function open_item(ctx, state, parent_win)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local item = item_at_line(state, cursor[1])
	if not item then
		return false
	end
	local child_ctx = {
		state = state,
		notify = ctx.notify,
		parent_win = parent_win,
	}
	if item.kind == "tool" then
		return pi_tool_output.open_float(child_ctx, item.output_id)
	elseif item.kind == "thinking" then
		return pi_thinking_output.open_float(child_ctx, item.output_id)
	elseif item.kind == "skill" then
		return pi_skills.open_float(child_ctx, item.output_id)
	end
	return false
end

function M.open(ctx, path, title)
	if not path or vim.fn.filereadable(path) ~= 1 then
		ctx.notify("Could not read " .. tostring(path), vim.log.levels.WARN)
		return
	end

	local state = {
		tool_outputs = {},
		next_tool_output_id = 0,
		tool_calls = {},
		live_tool_output_by_call = {},
		thinking_outputs = {},
		next_thinking_output_id = 0,
		skill_tool_calls = {},
		skill_outputs = {},
		next_skill_output_id = 0,
		transcript_items = {},
		transcript_buf = nil,
		transcript_win = nil,
	}

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "pi://defer/transcript/" .. vim.fn.fnamemodify(path, ":h:t"))
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
	pcall(vim.treesitter.start, buf, "markdown")

	state.transcript_buf = buf

	local function refresh()
		local lines = render_lines(path, state)
		set_modifiable(buf, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		set_modifiable(buf, false)
		if state.transcript_win then
			render_transcript_ui(state)
		end
	end
	refresh()

	local width = math.min(math.max(72, math.floor(vim.o.columns * 0.82)), vim.o.columns - 4)
	local height = math.min(math.max(16, math.floor(vim.o.lines * 0.75)), vim.o.lines - 4)
	local row = math.max(1, math.floor((vim.o.lines - height) / 2))
	local col = math.max(0, math.floor((vim.o.columns - width) / 2))
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " " .. (title or "Defer transcript") .. " ",
		title_pos = "left",
	})
	state.transcript_win = win
	vim.api.nvim_set_option_value("wrap", true, { win = win })
	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
	render_transcript_ui(state)

	local close_win = function()
		floats.close_window(win)
	end
	floats.close_on_win_leave(buf, close_win, { win = win, parent = ctx.parent_win })
	vim.keymap.set("n", "q", close_win, { buffer = buf, silent = true, desc = "Close defer transcript" })
	vim.keymap.set("n", "<Esc>", close_win, { buffer = buf, silent = true, desc = "Close defer transcript" })
	vim.keymap.set("n", "r", function()
		refresh()
		ctx.notify("Refreshed defer transcript")
	end, { buffer = buf, silent = true, desc = "Refresh defer transcript" })
	vim.keymap.set("n", "<CR>", function()
		open_item(ctx, state, win)
	end, { buffer = buf, silent = true, desc = "Open nested defer item" })
end

return M

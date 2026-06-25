local M = {}

local tree_preview_augroup = vim.api.nvim_create_augroup("PiNvimTreePreview", { clear = true })

local INITIAL_SESSION_NOTICE = "No Pi session started yet. Send a message or pick a session."
local NEW_SESSION_NOTICE = "New session."
local PENDING_NEW_SESSION_NOTICE = "New session will be created when you send a message."

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
	defer_buf = nil,
	defer_win = nil,
	tree_buf = nil,
	tree_win = nil,
	tree_preview_buf = nil,
	tree_preview_win = nil,
	tree_nodes_by_line = {},
	tree_leaf_id = nil,
	tree_filter_mode = "default",
	is_streaming = false,
	access_mode = "readonly",
	pending_access_mode = nil,
	current_message_started = false,
	session_file = nil,
	pending_session_file = nil,
	session_name = nil,
	message_count = 0,
	provider = nil,
	model_id = nil,
	thinking_level = nil,
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
	tool_outputs = {},
	next_tool_output_id = 0,
	pending_tool_separator = false,
	session_stats = nil,
	todo_status = nil,
	notification_status = nil,
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
		"thinking: " .. yaml_value(state.thinking_level),
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

local preserve_focused_transcript_view
local update_transcript_bottom_padding
local update_transcript_statusline

local function update_metadata()
	if not valid_buf(state.transcript_buf) then
		return
	end
	preserve_focused_transcript_view(function()
		set_modifiable(state.transcript_buf, true)
		local end_line = metadata_end()
		local lines = metadata_lines()
		if end_line then
			vim.api.nvim_buf_set_lines(state.transcript_buf, 0, end_line, false, lines)
		else
			vim.api.nvim_buf_set_lines(state.transcript_buf, 0, 0, false, lines)
		end
		set_modifiable(state.transcript_buf, false)
	end)
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
	update_transcript_bottom_padding()
	update_transcript_statusline()
	render_transcript()
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

local transcript_padding_ns = vim.api.nvim_create_namespace("pi-nvim-transcript-padding")

local function transcript_line_count()
	if not valid_buf(state.transcript_buf) then
		return 0
	end
	return vim.api.nvim_buf_line_count(state.transcript_buf)
end

update_transcript_bottom_padding = function()
	if not valid_buf(state.transcript_buf) then
		return
	end

	vim.api.nvim_buf_clear_namespace(state.transcript_buf, transcript_padding_ns, 0, -1)
	local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
	if line_count < 1 then
		return
	end

	vim.api.nvim_buf_set_extmark(state.transcript_buf, transcript_padding_ns, line_count - 1, 0, {
		virt_lines = { { { " ", "Normal" } } },
		virt_lines_above = false,
		virt_lines_leftcol = true,
		priority = 1,
	})
end

local function transcript_win_valid()
	return state.transcript_win and vim.api.nvim_win_is_valid(state.transcript_win)
end

local function non_null(value)
	return value ~= nil and value ~= vim.NIL
end

local function format_count(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fk", value / 1000)
	end
	return tostring(value)
end

local function format_session_stats()
	local stats = state.session_stats
	if not stats then
		return "tokens: --"
	end

	local tokens = stats.tokens or {}
	local parts = {
		"↑" .. format_count(tokens.input),
		"↓" .. format_count(tokens.output),
	}

	-- Pi core currently reports cacheRead/cacheWrite as cumulative per-request
	-- token events. For statusline purposes, show the session cache footprint
	-- instead: the largest cache read/write reported by any single model turn.
	local cache_read = tonumber(tokens.sessionCacheRead or tokens.cacheRead) or 0
	local cache_write = tonumber(tokens.sessionCacheWrite or tokens.cacheWrite) or 0
	if cache_read > 0 or cache_write > 0 then
		table.insert(parts, "R" .. format_count(cache_read))
		table.insert(parts, "W" .. format_count(cache_write))
	end

	local context = stats.contextUsage
	if context then
		local context_tokens = non_null(context.tokens) and format_count(context.tokens) or "?"
		local context_window = non_null(context.contextWindow) and format_count(context.contextWindow) or "?"
		table.insert(parts, "ctx " .. context_tokens .. "/" .. context_window)
	end

	if non_null(stats.cost) then
		table.insert(parts, string.format("$%.3f", stats.cost))
	end

	return table.concat(parts, "·")
end

local function statusline_escape(text)
	return tostring(text or ""):gsub("%%", "%%%%")
end

local function truncate_plain_to_width(text, width)
	if vim.fn.strdisplaywidth(text) <= width then
		return text
	end

	local result = ""
	for _, char in ipairs(vim.fn.split(text, "\\zs")) do
		local next_result = result .. char
		if vim.fn.strdisplaywidth(next_result) > width then
			break
		end
		result = next_result
	end
	return result
end

local function mode_statusline_highlight(mode)
	if mode == "readonly" then
		return "%#PiModeReadonly#"
	elseif mode == "write" then
		return "%#PiModeWrite#"
	end
	return "%#PiModeUnknown#"
end

local function current_model_statusline_label()
	local model = state.model_id or M.config.model
	local provider = state.provider or M.config.provider
	if type(model) ~= "string" or model == "" then
		return "--"
	end
	if type(provider) == "string" and provider ~= "" and not model:find("/", 1, true) then
		return provider .. "/" .. model
	end
	return model
end

local function current_thinking_level_label()
	local level = state.thinking_level
	if type(level) ~= "string" or level == "" then
		return nil
	end
	return level
end

local function thinking_statusline_highlight(level)
	if level == "off" then
		return "%#PiThinkingOff#"
	elseif level == "minimal" then
		return "%#PiThinkingMinimal#"
	elseif level == "low" then
		return "%#PiThinkingLow#"
	elseif level == "medium" then
		return "%#PiThinkingMedium#"
	elseif level == "high" then
		return "%#PiThinkingHigh#"
	elseif level == "xhigh" then
		return "%#PiThinkingXhigh#"
	end
	return "%#PiUsageStats#"
end

local function notification_statusline_highlight(status)
	if status == "notify on" then
		return "%#PiNotifyOn#"
	elseif status == "notify off" then
		return "%#PiNotifyOff#"
	end
	return "%#PiUsageStats#"
end

_G._pi_nvim_transcript_statusline = function()
	local mode = state.access_mode or "--"
	local mode_prefix = " "
	local mode_suffix = ""
	local mode_label = mode_prefix .. mode .. mode_suffix
	local status_delimiter = "·"
	local todo_label = state.todo_status and (status_delimiter .. state.todo_status) or ""
	local notification_label = state.notification_status and (status_delimiter .. state.notification_status) or ""
	local model_label = status_delimiter .. current_model_statusline_label()
	local thinking_level = current_thinking_level_label()
	local thinking_label = thinking_level and (" [" .. thinking_level .. "]") or ""
	local stats_label = " " .. format_session_stats() .. " "
	local width = vim.api.nvim_win_get_width(0)
	local mode_width = vim.fn.strdisplaywidth(mode_label)
	local todo_width = vim.fn.strdisplaywidth(todo_label)
	local notification_width = vim.fn.strdisplaywidth(notification_label)
	local model_width = vim.fn.strdisplaywidth(model_label)
	local thinking_width = vim.fn.strdisplaywidth(thinking_label)
	local left_width = mode_width + todo_width + notification_width + model_width + thinking_width
	local stats_width = vim.fn.strdisplaywidth(stats_label)
	local show_stats = width >= (left_width + stats_width + 3)
	local mode_highlight = mode_statusline_highlight(mode)

	if width <= mode_width then
		local prefix_width = vim.fn.strdisplaywidth(mode_prefix)
		if width <= prefix_width then
			return "%#PiUsageStats#" .. statusline_escape(truncate_plain_to_width(mode_prefix, width)) .. "%*"
		end
		return "%#PiUsageStats#"
			.. statusline_escape(mode_prefix)
			.. mode_highlight
			.. statusline_escape(truncate_plain_to_width(mode .. mode_suffix, width - prefix_width))
			.. "%*"
	end

	local left_label = "%#PiUsageStats#"
		.. statusline_escape(mode_prefix)
		.. mode_highlight
		.. statusline_escape(mode)
		.. "%#PiUsageStats#"
		.. statusline_escape(mode_suffix)

	if width <= left_width then
		return left_label
			.. "%#PiUsageStats#"
			.. statusline_escape(truncate_plain_to_width(todo_label .. notification_label .. model_label .. thinking_label, width - mode_width))
			.. "%*"
	end

	left_label = left_label .. "%#PiUsageStats#" .. statusline_escape(todo_label)
	if notification_label ~= "" then
		left_label = left_label
			.. notification_statusline_highlight(state.notification_status)
			.. statusline_escape(notification_label)
			.. "%#PiUsageStats#"
	end
	left_label = left_label .. statusline_escape(model_label)
	if thinking_label ~= "" then
		left_label = left_label
			.. thinking_statusline_highlight(thinking_level)
			.. statusline_escape(thinking_label)
			.. "%#PiUsageStats#"
	end
	local right_label = show_stats and ("%#PiUsageStats#" .. statusline_escape(stats_label)) or ""
	local right_width = show_stats and stats_width or 0
	local fill_width = math.max(0, width - left_width - right_width)
	return left_label .. "%#PiPaneBorder#" .. string.rep("─", fill_width) .. right_label .. "%*"
end

update_transcript_statusline = function()
	if not transcript_win_valid() then
		return
	end
	vim.api.nvim_set_option_value("statusline", "%!v:lua._pi_nvim_transcript_statusline()", { win = state.transcript_win })
	vim.cmd("redrawstatus!")
end

local function transcript_is_focused()
	return transcript_win_valid() and vim.api.nvim_get_current_win() == state.transcript_win
end

local function scroll_transcript_to_bottom_unless_focused()
	if transcript_win_valid() and not transcript_is_focused() then
		vim.api.nvim_win_set_cursor(state.transcript_win, { vim.api.nvim_buf_line_count(state.transcript_buf), 0 })
	end
end

preserve_focused_transcript_view = function(callback)
	if not transcript_is_focused() then
		callback()
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(state.transcript_win)
	local view = vim.fn.winsaveview()
	callback()

	if not transcript_win_valid() or not valid_buf(state.transcript_buf) then
		return
	end
	local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
	cursor[1] = math.min(cursor[1], line_count)
	vim.api.nvim_win_set_cursor(state.transcript_win, cursor)
	view.lnum = cursor[1]
	vim.fn.winrestview(view)
end

local function with_transcript_win(callback)
	if not transcript_win_valid() then
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
	state.pending_tool_separator = false
	if type(lines) == "string" then
		lines = vim.split(lines, "\n", { plain = true })
	end
	preserve_focused_transcript_view(function()
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
	end)
	update_transcript_bottom_padding()
	scroll_transcript_to_bottom_unless_focused()
	schedule_transcript_refresh()
end

local function append_text(text)
	if not valid_buf(state.transcript_buf) or text == nil or text == "" then
		return
	end

	local parts = vim.split(text, "\n", { plain = true })
	preserve_focused_transcript_view(function()
		set_modifiable(state.transcript_buf, true)

		local last = vim.api.nvim_buf_line_count(state.transcript_buf)
		local current = vim.api.nvim_buf_get_lines(state.transcript_buf, last - 1, last, false)[1] or ""
		if state.pending_tool_separator and current == "" then
			vim.api.nvim_buf_set_lines(state.transcript_buf, last, last, false, { parts[1] })
			last = last + 1
		else
			vim.api.nvim_buf_set_lines(state.transcript_buf, last - 1, last, false, { current .. parts[1] })
		end
		state.pending_tool_separator = false

		if #parts > 1 then
			local rest = {}
			for i = 2, #parts do
				table.insert(rest, parts[i])
			end
			vim.api.nvim_buf_set_lines(state.transcript_buf, last, last, false, rest)
		end

		set_modifiable(state.transcript_buf, false)
	end)
	update_transcript_bottom_padding()
	scroll_transcript_to_bottom_unless_focused()
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

local function line_count_text(text)
	if type(text) ~= "string" or text == "" then
		return 0
	end
	local _, count = text:gsub("\n", "")
	if text:sub(-1) == "\n" then
		return count
	end
	return count + 1
end

local function looks_like_json(text)
	if type(text) ~= "string" then
		return false
	end
	local trimmed = vim.trim(text)
	if not (trimmed:sub(1, 1) == "{" or trimmed:sub(1, 1) == "[") then
		return false
	end
	local ok = pcall(vim.json.decode, trimmed)
	return ok
end

local function infer_tool_filetype(tool_name, text)
	if looks_like_json(text) then
		return "json"
	end
	if tool_name == "edit" or tool_name == "write" then
		return "diff"
	end
	return "text"
end

local function reset_tool_outputs()
	state.tool_outputs = {}
	state.next_tool_output_id = 0
end

local open_defer_text

local function path_from_artifact_line(text, label)
	if type(text) ~= "string" then
		return nil
	end
	return text:match("%- " .. label .. ": ([^\n]+)")
end

local function defer_artifacts(tool_name, text, details)
	if tool_name ~= "defer_task" then
		return nil
	end
	details = type(details) == "table" and details or {}
	local artifacts = {
		brief = details.briefPath or path_from_artifact_line(text, "Brief"),
		result = details.resultPath or path_from_artifact_line(text, "Result"),
		transcript = details.transcriptPath or path_from_artifact_line(text, "Transcript"),
		status = details.statusPath or path_from_artifact_line(text, "Status"),
	}
	if artifacts.brief or artifacts.result or artifacts.transcript or artifacts.status then
		return artifacts
	end
	return nil
end

local function store_tool_output(tool_name, text, filetype, details)
	state.next_tool_output_id = state.next_tool_output_id + 1
	local id = state.next_tool_output_id
	state.tool_outputs[id] = {
		name = tool_name or "tool",
		text = text or "",
		filetype = filetype or infer_tool_filetype(tool_name, text),
		details = details,
		defer = defer_artifacts(tool_name, text, details),
	}
	return id
end

local function tool_output_summary_lines(output_id)
	local output = state.tool_outputs[output_id]
	if not output then
		return { "> Tool output unavailable." }
	end
	local lines = line_count_text(output.text)
	local line_label = lines == 1 and "1 line" or (tostring(lines) .. " lines")
	local action = output.defer and "open defer artifacts" or "open"
	return {
		"> Tool: " .. tostring(output.name or "tool") .. " · " .. line_label .. " · " .. (output.filetype or "text") .. " · press `<CR>` to " .. action,
	}
end

local function remove_pending_tool_separator()
	if not state.pending_tool_separator or not valid_buf(state.transcript_buf) then
		return false
	end

	local removed = false
	preserve_focused_transcript_view(function()
		set_modifiable(state.transcript_buf, true)
		local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
		local last_line = vim.api.nvim_buf_get_lines(state.transcript_buf, line_count - 1, line_count, false)[1]
		if last_line == "" then
			vim.api.nvim_buf_set_lines(state.transcript_buf, line_count - 1, line_count, false, {})
			removed = true
		end
		set_modifiable(state.transcript_buf, false)
	end)
	state.pending_tool_separator = false
	return removed
end

local function remove_status(text)
	if not valid_buf(state.transcript_buf) then
		return
	end
	local target = "> " .. text
	preserve_focused_transcript_view(function()
		set_modifiable(state.transcript_buf, true)
		local lines = vim.api.nvim_buf_get_lines(state.transcript_buf, 0, -1, false)
		for index = #lines, 1, -1 do
			if lines[index] == target then
				vim.api.nvim_buf_set_lines(state.transcript_buf, index - 1, index, false, {})
			end
		end
		set_modifiable(state.transcript_buf, false)
	end)
	update_transcript_bottom_padding()
	schedule_transcript_refresh()
end

local function create_tool_fold(start_line, end_line, header_line, output_id)
	if end_line < start_line then
		return
	end

	-- If the tool body starts with blank separator lines, don't include those in
	-- the closed fold. Otherwise a closed fold can look like an empty line under
	-- the tool header even though output exists.
	local fold_start = start_line
	local lines = vim.api.nvim_buf_get_lines(state.transcript_buf, start_line - 1, end_line, false)
	for index, line in ipairs(lines) do
		if line ~= "" then
			fold_start = start_line + index - 1
			break
		end
	end

	table.insert(state.tool_folds, {
		header_line = header_line or math.max(1, fold_start - 1),
		start_line = fold_start,
		end_line = end_line,
		output_id = output_id,
	})

	if end_line <= fold_start then
		return
	end

	with_transcript_win(function()
		local cursor = vim.api.nvim_win_get_cursor(state.transcript_win)
		local view = vim.fn.winsaveview()
		local cursor_at_or_after_fold = cursor[1] >= fold_start
		vim.cmd(string.format("%d,%dfold", fold_start, end_line))
		vim.api.nvim_win_set_cursor(state.transcript_win, { fold_start, 0 })
		vim.cmd("normal! zc")
		local line_count = transcript_line_count()
		if cursor_at_or_after_fold then
			vim.api.nvim_win_set_cursor(state.transcript_win, { math.min(end_line + 1, line_count), 0 })
			vim.cmd("normal! zb")
		else
			vim.api.nvim_win_set_cursor(state.transcript_win, { math.min(cursor[1], line_count), cursor[2] })
			vim.fn.winrestview(view)
		end
	end)
end

local function start_tool_fold(output_id)
	local line_count = transcript_line_count()
	state.active_tool_fold = {
		header_line = math.max(1, line_count - 1),
		start_line = line_count,
		output_id = output_id,
	}
end

local function append_tool_fold_separator()
	-- append_lines() intentionally coalesces leading blank lines with an existing
	-- trailing blank. Here we specifically need one line outside the fold, even
	-- when the tool output itself ended with a blank line inside the folded range.
	preserve_focused_transcript_view(function()
		set_modifiable(state.transcript_buf, true)
		local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
		vim.api.nvim_buf_set_lines(state.transcript_buf, line_count, line_count, false, { "" })
		set_modifiable(state.transcript_buf, false)
	end)
	state.pending_tool_separator = true
	update_transcript_bottom_padding()
	schedule_transcript_refresh()
end

local function finish_tool_fold()
	if not state.active_tool_fold then
		return
	end

	local tool_fold = state.active_tool_fold
	state.active_tool_fold = nil
	local end_line = transcript_line_count()
	append_tool_fold_separator()
	create_tool_fold(tool_fold.start_line, end_line, tool_fold.header_line, tool_fold.output_id)
end

local function line_in_tool_fold(line)
	for _, tool_fold in ipairs(state.tool_folds) do
		local header_line = tool_fold.header_line or math.max(1, tool_fold.start_line - 1)
		if line >= header_line and line <= tool_fold.end_line then
			return tool_fold
		end
	end
	return nil
end

local function sanitize_buf_name_part(value)
	return tostring(value or "tool"):gsub("[^%w%._%-]+", "-")
end

local function close_window(win)
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

local function open_defer_artifacts(output)
	if not output.defer then
		return false
	end
	local choices = {}
	local function add(label, path, filetype)
		if path and path ~= "" then
			table.insert(choices, { label = label, path = path, filetype = filetype })
		end
	end
	add("result", output.defer.result, "markdown")
	add("transcript", output.defer.transcript, "json")
	add("brief", output.defer.brief, "markdown")
	add("status", output.defer.status, "json")
	if #choices == 0 then
		notify("No defer artifacts found for this tool call", vim.log.levels.WARN)
		return true
	end
	vim.ui.select(choices, {
		prompt = "Open defer artifact",
		format_item = function(item)
			return item.label .. "  " .. item.path
		end,
	}, function(choice)
		if choice and open_defer_text then
			open_defer_text("Defer " .. choice.label, choice.path, choice.filetype)
		end
	end)
	return true
end

local function open_tool_output_float(output_id)
	local output = state.tool_outputs[output_id]
	if not output then
		notify("Tool output unavailable", vim.log.levels.WARN)
		return true
	end
	if output.defer and open_defer_artifacts(output) then
		return true
	end

	local width = math.max(40, math.floor(vim.o.columns * 0.85))
	local height = math.max(10, math.floor(vim.o.lines * 0.8))
	width = math.min(width, math.max(1, vim.o.columns - 4))
	height = math.min(height, math.max(1, vim.o.lines - 4))
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "pi://tool/" .. output_id .. "/" .. sanitize_buf_name_part(output.name))
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", output.filetype or "text", { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(output.text or "", "\n", { plain = true }))
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Tool: " .. tostring(output.name or "tool") .. " ",
		title_pos = "left",
	})

	vim.api.nvim_set_option_value("wrap", false, { win = win })
	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })

	vim.keymap.set("n", "q", function()
		close_window(win)
	end, { buffer = buf, silent = true, desc = "Close tool output" })
	vim.keymap.set("n", "<Esc>", function()
		close_window(win)
	end, { buffer = buf, silent = true, desc = "Close tool output" })
	vim.keymap.set("n", "y", function()
		vim.fn.setreg("+", output.text or "")
		notify("Yanked tool output")
	end, { buffer = buf, silent = true, desc = "Yank tool output" })

	return true
end

local function open_tool_output_under_cursor()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local tool_fold = line_in_tool_fold(cursor[1])
	if not tool_fold or not tool_fold.output_id then
		return false
	end
	return open_tool_output_float(tool_fold.output_id)
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
	preserve_focused_transcript_view(function()
		set_modifiable(state.transcript_buf, true)
		vim.api.nvim_buf_set_lines(state.transcript_buf, state.placeholder_line - 1, state.placeholder_line, false, { text })
		set_modifiable(state.transcript_buf, false)
	end)
	update_transcript_bottom_padding()
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
	preserve_focused_transcript_view(function()
		set_modifiable(state.transcript_buf, true)
		vim.api.nvim_buf_set_lines(state.transcript_buf, start_line, end_line, false, {})
		set_modifiable(state.transcript_buf, false)
	end)
	state.placeholder_start_line = nil
	state.placeholder_line = nil
	update_transcript_bottom_padding()
	schedule_transcript_refresh()
end

local function clear_assistant_placeholder_spinner()
	stop_placeholder_timer()
	if not valid_buf(state.transcript_buf) or not state.placeholder_line then
		state.placeholder_start_line = nil
		state.placeholder_line = nil
		return
	end
	local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
	if state.placeholder_line < 1 or state.placeholder_line > line_count then
		state.placeholder_start_line = nil
		state.placeholder_line = nil
		return
	end
	preserve_focused_transcript_view(function()
		set_modifiable(state.transcript_buf, true)
		vim.api.nvim_buf_set_lines(state.transcript_buf, state.placeholder_line - 1, state.placeholder_line, false, {})
		set_modifiable(state.transcript_buf, false)
	end)
	state.placeholder_start_line = nil
	state.placeholder_line = nil
	update_transcript_bottom_padding()
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

function M.refresh_session_stats()
	send({ type = "get_session_stats" }, function(event)
		if event.success and event.data then
			state.session_stats = event.data
			update_transcript_statusline()

			send({ type = "get_messages" }, function(messages_event)
				if messages_event.success and messages_event.data then
					apply_session_cache_footprint(state.session_stats, messages_event.data.messages)
					update_transcript_statusline()
				end
			end)
		end
	end)
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
		local output_id = store_tool_output(name, text, nil, message.details)
		remove_pending_tool_separator()
		append_lines(tool_output_summary_lines(output_id))
		local line = transcript_line_count()
		table.insert(state.tool_folds, {
			header_line = line,
			start_line = line,
			end_line = line,
			output_id = output_id,
		})
		append_tool_fold_separator()
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
	}
end

local function confirm_with_preview(event)
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
		elseif event.statusKey == "pi-tree-leaf" then
			state.tree_leaf_id = event.statusText
		elseif event.statusKey == "pi-todos" then
			state.todo_status = event.statusText
			refresh_transcript_ui()
		elseif event.statusKey == "pi-notifications" then
			state.notification_status = event.statusText
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
		if not state.current_message_started then
			clear_assistant_placeholder()
			append_message_header("Assistant")
		end
		state.current_message_started = true
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
		clear_assistant_placeholder_spinner()
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
		M.refresh_session_stats()
		notify("Pi finished")
	elseif event.type == "message_update" then
		handle_message_update(event)
	elseif event.type == "message_end" then
		if
			event.message
			and event.message.role == "user"
			and state.pending_user_message
			and vim.trim(extract_text(event.message) or "") == state.pending_user_message
		then
			state.pending_user_message = nil
			return
		end
		if event.message and (event.message.role == "toolResult" or not state.current_message_started) then
			render_message(event.message)
		end
	elseif event.type == "tool_execution_start" then
		clear_assistant_placeholder_spinner()
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
	if state.pending_session_file and state.pending_session_file ~= "" then
		vim.list_extend(args, { "--session", vim.fn.expand(state.pending_session_file) })
	end
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

local function start_markdown_treesitter(buf)
	if not valid_buf(buf) then
		return
	end
	-- pi:// buffers are synthetic nofile buffers, so do not rely on the
	-- normal file read/filetype path to attach Tree-sitter and its injections.
	pcall(vim.treesitter.start, buf, "markdown")
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

local function register_pi_which_key()
	local ok, which_key = pcall(require, "which-key")
	if not ok then
		return
	end

	local shared = {
		{ "<leader>?", desc = "Pi help" },
		{ "<leader>/", desc = "Pick Pi command" },
		{ "<leader>h", desc = "History" },
		{ "<leader>m", desc = "Pick model" },
		{ "<leader>N", desc = "New session" },
		{ "<leader>n", desc = "Toggle notifications" },
		{ "<leader>p", desc = "Pick access mode" },
		{ "<leader>r", desc = "Refresh transcript" },
		{ "<leader>R", desc = "Rename session" },
		{ "<leader>s", desc = "Pick session" },
		{ "<leader>t", desc = "Pick thinking level" },
		{ "<leader>T", desc = "Session tree" },
		{ "<Tab>", desc = "Cycle access mode" },
	}

	if valid_buf(state.input_buf) then
		local input_specs = vim.deepcopy(shared)
		vim.list_extend(input_specs, {
			{ "<C-CR>", desc = "Submit prompt", mode = { "n", "i" } },
		})
		for _, spec in ipairs(input_specs) do
			spec.buffer = state.input_buf
		end
		which_key.add(input_specs)
	end

	if valid_buf(state.transcript_buf) then
		local transcript_specs = vim.deepcopy(shared)
		vim.list_extend(transcript_specs, {
			{ "<CR>", desc = "Open tool output / toggle fold" },
			{ "<Esc><Esc>", desc = "Abort Pi" },
		})
		for _, spec in ipairs(transcript_specs) do
			spec.buffer = state.transcript_buf
		end
		which_key.add(transcript_specs)
	end
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
	map_input("n", "<leader>/", function()
		M.pick_command()
	end, "Pick Pi command")
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
	map_input("n", "<leader>T", function()
		M.show_tree()
	end, "Session tree")
	map_input("n", "<leader>N", function()
		M.new_session()
	end, "New session")
	map_input("n", "<leader>n", function()
		M.toggle_notifications()
	end, "Toggle notifications")
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
	map_transcript("<leader>/", function()
		M.pick_command()
	end, "Pick Pi command")
	map_transcript("<leader>p", function()
		M.pick_access_mode()
	end, "Pick access mode")
	map_transcript("<leader>s", function()
		M.pick_session()
	end, "Pick session")
	map_transcript("<leader>h", function()
		M.history()
	end, "History")
	map_transcript("<leader>T", function()
		M.show_tree()
	end, "Session tree")
	map_transcript("<leader>N", function()
		M.new_session()
	end, "New session")
	map_transcript("<leader>n", function()
		M.toggle_notifications()
	end, "Toggle notifications")
	map_transcript("<leader>r", function()
		M.refresh_messages()
	end, "Refresh transcript")
	map_transcript("<leader>R", function()
		M.rename_session()
	end, "Rename session")
	map_transcript("<CR>", function()
		if open_tool_output_under_cursor() then
			return
		end
		if not toggle_tool_fold() then
			vim.cmd("normal! za")
		end
	end, "Open tool output or toggle fold")

	register_pi_which_key()
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
	start_markdown_treesitter(state.transcript_buf)
	start_markdown_treesitter(state.input_buf)

	vim.api.nvim_win_set_buf(0, state.transcript_buf)
	state.transcript_win = vim.api.nvim_get_current_win()
	apply_transcript_window_options(state.transcript_win)
	vim.cmd("botright 12split")
	vim.api.nvim_win_set_buf(0, state.input_buf)
	state.input_win = vim.api.nvim_get_current_win()
	apply_window_padding(state.input_win)

	refresh_transcript_ui()
	append_status(INITIAL_SESSION_NOTICE)

	setup_keymaps()
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
				if state.session_file and state.session_file ~= "" then
					state.pending_session_file = state.session_file
				end
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
			state.pending_session_file = nil
			apply_session_state(event.data)
			M.refresh_session_stats()
		end
	end)
	if state.pending_access_mode then
		local mode = state.pending_access_mode
		send({ type = "prompt", message = "/pi-mode " .. mode }, function(event)
			if event.success then
				state.pending_access_mode = nil
			else
				notify(event.error or "Could not set access mode", vim.log.levels.ERROR)
			end
		end)
	end
end

function M.submit_prompt()
	local text = get_input()
	if text == "" then
		return
	end
	state.abort_requested = false
	state.error_rendered_for_active_run = false
	clear_input()
	remove_status(INITIAL_SESSION_NOTICE)
	remove_status(NEW_SESSION_NOTICE)
	remove_status(PENDING_NEW_SESSION_NOTICE)
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

function M.toggle_notifications()
	send({ type = "prompt", message = "/pi-notify toggle" }, function(event)
		if not event.success then
			notify(event.error or "Could not toggle notifications", vim.log.levels.ERROR)
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
	if not (state.job and state.job > 0) then
		state.pending_session_file = nil
		state.session_file = nil
		set_modifiable(state.transcript_buf, true)
		vim.api.nvim_buf_set_lines(state.transcript_buf, 0, -1, false, {})
		set_modifiable(state.transcript_buf, false)
		delete_tool_folds()
		state.session_name = nil
		state.message_count = 0
		state.session_stats = nil
		state.todo_status = nil
		state.tree_leaf_id = nil
		refresh_transcript_ui()
		append_status(PENDING_NEW_SESSION_NOTICE)
		return
	end

	send({ type = "new_session" }, function(event)
		if event.success then
			set_modifiable(state.transcript_buf, true)
			vim.api.nvim_buf_set_lines(state.transcript_buf, 0, -1, false, {})
			set_modifiable(state.transcript_buf, false)
			delete_tool_folds()
			state.session_name = nil
			state.message_count = 0
			state.session_stats = nil
			state.todo_status = nil
			state.tree_leaf_id = nil
			refresh_transcript_ui()
			append_status(NEW_SESSION_NOTICE)
			send({ type = "get_state" }, function(state_event)
				if state_event.success and state_event.data then
					apply_session_state(state_event.data)
					M.refresh_session_stats()
				end
			end)
		end
	end)
end

local decode_session_record

local function apply_session_record_metadata(records)
	for _, record in ipairs(records or {}) do
		if record.type == "session_info" and type(record.name) == "string" then
			state.session_name = record.name
		elseif record.type == "model_change" then
			set_model_metadata(record.provider or record.providerId or record.providerName, record.modelId or record.model or record.id)
		elseif record.type == "thinking_level_change" and type(record.thinkingLevel) == "string" then
			state.thinking_level = record.thinkingLevel
		end
	end
end

local function load_session_messages_from_file(path)
	local fallback_messages = {}
	local all_records = {}
	local by_id = {}
	local leaf_id = nil
	if not path or vim.fn.filereadable(path) ~= 1 then
		return fallback_messages
	end
	for _, line in ipairs(vim.fn.readfile(path)) do
		local record = decode_session_record(line)
		if record then
			table.insert(all_records, record)
		end
		if record and record.id then
			by_id[record.id] = record
			leaf_id = record.id
		end
		if record and record.type == "message" and record.message then
			table.insert(fallback_messages, record.message)
		end
	end

	local branch = {}
	local seen = {}
	local id = leaf_id
	while id and by_id[id] and not seen[id] do
		seen[id] = true
		local record = by_id[id]
		table.insert(branch, 1, record)
		id = record.parentId
	end

	apply_session_record_metadata(#branch > 0 and branch or all_records)

	local messages = {}
	for _, record in ipairs(branch) do
		if record.type == "message" and record.message then
			table.insert(messages, record.message)
		end
	end
	return #messages > 0 and messages or fallback_messages
end

local function message_role_title(message)
	local role = message.role or message.type or "message"
	return role:gsub("^%l", string.upper)
end

local function add_message_separator(lines, has_body)
	if has_body then
		vim.list_extend(lines, { "", "---", "" })
	else
		table.insert(lines, "")
	end
end

local function collect_message_lines(messages)
	local lines = metadata_lines()
	local folds = {}
	local has_body = false
	local last_role = nil

	for _, message in ipairs(messages or {}) do
		local text = extract_text(message)
		if text and text ~= "" then
			local role = message.role or message.type
			if role == "toolResult" then
				local name = message.toolName or "tool"
				local output_id = store_tool_output(name, text, nil, message.details)
				if has_body and last_role == "toolResult" then
					if lines[#lines] == "" then
						table.remove(lines)
					end
				else
					add_message_separator(lines, has_body)
				end
				vim.list_extend(lines, tool_output_summary_lines(output_id))
				local line = #lines
				table.insert(lines, "")
				table.insert(folds, {
					header_line = line,
					start_line = line,
					end_line = line,
					output_id = output_id,
				})
			else
				local text_lines = vim.split(text, "\n", { plain = true })
				add_message_separator(lines, has_body)
				table.insert(lines, "## " .. message_role_title(message))
				table.insert(lines, "")
				vim.list_extend(lines, text_lines)
			end
			has_body = true
			last_role = role
		end
	end

	return lines, folds
end

local function apply_collected_tool_folds(folds)
	state.tool_folds = folds or {}
	state.active_tool_fold = nil
	with_transcript_win(function()
		vim.cmd("normal! zE")
		for _, tool_fold in ipairs(state.tool_folds) do
			if tool_fold.end_line > tool_fold.start_line then
				vim.cmd(string.format("%d,%dfold", tool_fold.start_line, tool_fold.end_line))
				vim.api.nvim_win_set_cursor(state.transcript_win, { tool_fold.start_line, 0 })
				vim.cmd("normal! zc")
			end
		end
	end)
end

local function scroll_transcript_to_bottom()
	if transcript_win_valid() and valid_buf(state.transcript_buf) then
		vim.api.nvim_win_set_cursor(state.transcript_win, { vim.api.nvim_buf_line_count(state.transcript_buf), 0 })
		with_transcript_win(function()
			vim.cmd("normal! zb")
		end)
	end
end

local function render_messages(messages)
	if not valid_buf(state.transcript_buf) then
		return
	end

	state.last_updated = os.date("%Y-%m-%d %H:%M:%S %z")
	reset_tool_outputs()
	local lines, folds = collect_message_lines(messages)
	set_buffer_lines(state.transcript_buf, lines, false)
	apply_collected_tool_folds(folds)
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

local function tree_decode_record(line)
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

local function tree_record_text(record)
	if record.type == "message" and record.message then
		if record.message.role == "bashExecution" then
			return record.message.command or record.message.output or "bash execution"
		end
		return extract_text(record.message) or ""
	elseif record.type == "branch_summary" then
		return record.summary or "branch summary"
	elseif record.type == "compaction" then
		return record.summary or "compaction summary"
	elseif record.type == "bashExecution" then
		return record.command or record.output or "bash execution"
	elseif record.type == "custom_message" then
		return extract_text(record) or record.content or "custom message"
	elseif record.type == "model_change" then
		return table.concat(vim.tbl_filter(function(part)
			return part and part ~= ""
		end, { record.provider, record.modelId }), "/")
	elseif record.type == "thinking_level_change" then
		return record.thinkingLevel or "thinking level changed"
	elseif record.type == "label" then
		return record.label or "label cleared"
	end
	return ""
end

local function tree_record_title(record)
	if record.type == "message" and record.message then
		local role = record.message.role or "message"
		if role == "bashExecution" then
			return "Bash"
		elseif role == "toolResult" then
			return "Tool"
		end
		return role:gsub("^%l", string.upper)
	elseif record.type == "branch_summary" then
		return "Branch summary"
	elseif record.type == "compaction" then
		return "Compaction"
	elseif record.type == "bashExecution" then
		return "Bash"
	elseif record.type == "custom_message" then
		return "Custom"
	elseif record.type == "model_change" then
		return "Model"
	elseif record.type == "thinking_level_change" then
		return "Thinking"
	elseif record.type == "label" then
		return "Label"
	end
	return record.type or "entry"
end

local function tree_message_has_visible_text(message)
	return vim.trim(extract_text(message) or "") ~= ""
end

local function tree_is_tool_record(record)
	if record.type == "bashExecution" then
		return true
	end
	if record.type ~= "message" or not record.message then
		return false
	end
	local role = record.message.role
	if role == "toolResult" or role == "bashExecution" then
		return true
	end
	-- Assistant messages that only contain tool calls/thinking have no user-facing
	-- text and clutter the navigation tree. Keep them available in "all" mode.
	if role == "assistant" and not tree_message_has_visible_text(record.message) then
		return true
	end
	return false
end

local function tree_record_visible(record, mode)
	mode = mode or state.tree_filter_mode or "default"
	if not M.config.tree_entry_types[record.type] then
		return false
	end
	if mode == "all" then
		return true
	end
	if mode == "user-only" then
		return record.type == "message" and record.message and record.message.role == "user"
	end
	if mode == "no-tools" or mode == "default" then
		if not vim.tbl_contains({ "message", "branch_summary", "compaction", "custom_message" }, record.type) then
			return false
		end
		return not tree_is_tool_record(record)
	end
	return not tree_is_tool_record(record)
end

local function cycle_tree_filter_mode()
	local modes = M.config.tree_filter_modes or { "default", "no-tools", "user-only", "all" }
	local current = state.tree_filter_mode or modes[1]
	for index, mode in ipairs(modes) do
		if mode == current then
			state.tree_filter_mode = modes[(index % #modes) + 1]
			return state.tree_filter_mode
		end
	end
	state.tree_filter_mode = modes[1]
	return state.tree_filter_mode
end

local function compact_tree_text(text)
	text = tostring(text or ""):gsub("%s+", " ")
	text = vim.trim(text)
	if text == "" then
		return "(no text)"
	end
	if #text > 96 then
		return text:sub(1, 93) .. "..."
	end
	return text
end

local function visible_tree_parent(record, visible_by_id, by_id)
	local parent_id = record.parentId
	local seen = {}
	while parent_id and by_id[parent_id] and not seen[parent_id] do
		if visible_by_id[parent_id] then
			return parent_id
		end
		seen[parent_id] = true
		parent_id = by_id[parent_id].parentId
	end
	return nil
end

local function nearest_visible_tree_id(id, visible_by_id, by_id)
	local seen = {}
	while id and by_id[id] and not seen[id] do
		if visible_by_id[id] then
			return id
		end
		seen[id] = true
		id = by_id[id].parentId
	end
	return nil
end

local function read_session_tree(path)
	local records = {}
	local by_id = {}
	local visible_by_id = {}
	local last_id = nil
	if not path or vim.fn.filereadable(path) ~= 1 then
		return {}, nil
	end

	for _, line in ipairs(vim.fn.readfile(path)) do
		local record = tree_decode_record(line)
		if record and record.id then
			by_id[record.id] = record
			last_id = record.id
			if tree_record_visible(record, state.tree_filter_mode) then
				table.insert(records, record)
				visible_by_id[record.id] = true
			end
		end
	end

	local nodes_by_id = {}
	local roots = {}
	for _, record in ipairs(records) do
		nodes_by_id[record.id] = {
			record = record,
			children = {},
		}
	end
	for _, record in ipairs(records) do
		local node = nodes_by_id[record.id]
		local parent_id = visible_tree_parent(record, visible_by_id, by_id)
		if parent_id and nodes_by_id[parent_id] then
			table.insert(nodes_by_id[parent_id].children, node)
		else
			table.insert(roots, node)
		end
	end

	local leaf_id = nearest_visible_tree_id(state.tree_leaf_id, visible_by_id, by_id)
		or nearest_visible_tree_id(last_id, visible_by_id, by_id)
	return roots, leaf_id
end

local function render_tree_nodes(nodes, leaf_id, lines, line_nodes, prefix)
	for index, node in ipairs(nodes) do
		local is_last = index == #nodes
		local connector = prefix == "" and "" or (is_last and "└─ " or "├─ ")
		local child_prefix = prefix .. (is_last and "   " or "│  ")
		local record = node.record
		local current = record.id == leaf_id
		local marker = current and "●" or "○"
		local label = string.format(
			"%s%s %s %s  %s  %s",
			prefix,
			connector,
			marker,
			record.id,
			tree_record_title(record),
			compact_tree_text(tree_record_text(record))
		)
		if current then
			label = label .. "  ← current"
		end
		table.insert(lines, label)
		line_nodes[#lines] = node
		render_tree_nodes(node.children, leaf_id, lines, line_nodes, child_prefix)
	end
end

local function focus_input_window()
	if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
		vim.api.nvim_set_current_win(state.input_win)
	end
end

local function close_tree_window()
	if state.tree_win and vim.api.nvim_win_is_valid(state.tree_win) then
		vim.api.nvim_win_close(state.tree_win, true)
	end
	if state.tree_preview_win and vim.api.nvim_win_is_valid(state.tree_preview_win) then
		vim.api.nvim_win_close(state.tree_preview_win, true)
	end
	state.tree_win = nil
	state.tree_preview_win = nil
end

local function tree_current_node()
	local cursor = vim.api.nvim_win_get_cursor(0)
	return state.tree_nodes_by_line[cursor[1]]
end

local function tree_preview_lines(node)
	if not node or not node.record then
		return { "No tree entry selected." }
	end
	local record = node.record
	local lines = {
		string.format("%s  %s", tree_record_title(record), record.id or ""),
	}
	if record.parentId then
		table.insert(lines, "parent: " .. record.parentId)
	end
	if record.timestamp then
		table.insert(lines, "time: " .. tostring(record.timestamp))
	end
	if record.type then
		table.insert(lines, "type: " .. tostring(record.type))
	end
	if record.type == "message" and record.message and record.message.role then
		table.insert(lines, "role: " .. tostring(record.message.role))
	end
	if record.type == "message" and record.message and record.message.toolName then
		table.insert(lines, "tool: " .. tostring(record.message.toolName))
	end
	if record.type == "model_change" then
		table.insert(lines, "model: " .. tree_record_text(record))
	elseif record.type == "thinking_level_change" then
		table.insert(lines, "thinking: " .. tree_record_text(record))
	end
	table.insert(lines, "")

	local text = tree_record_text(record)
	if text == "" and record.type == "message" and record.message then
		text = vim.inspect(record.message.content or record.message)
	end
	if text == "" then
		text = vim.inspect(record)
	end
	vim.list_extend(lines, vim.split(tostring(text), "\n", { plain = true }))
	return lines
end

local function update_tree_preview()
	if not valid_buf(state.tree_preview_buf) then
		return
	end
	set_buffer_lines(state.tree_preview_buf, tree_preview_lines(tree_current_node()), false)
end

local function jump_to_tree_node(summarize)
	local node = tree_current_node()
	if not node then
		return
	end
	local entry_id = node.record.id
	state.tree_leaf_id = entry_id
	close_tree_window()
	local message = "/pi-tree-jump " .. entry_id .. (summarize and " --summary" or "")
	if not (state.job and state.job > 0) then
		notify("Start Pi before navigating the session tree.", vim.log.levels.WARN)
		return
	end
	send({ type = "prompt", message = message }, function(event)
		if not event.success then
			notify(event.error or "Could not navigate session tree", vim.log.levels.ERROR)
			return
		end
		vim.defer_fn(function()
			M.refresh_messages()
			focus_input_window()
		end, 100)
	end)
end

function M.show_tree()
	local path = state.session_file or state.pending_session_file
	if not path or path == "" then
		notify("No Pi session selected yet.", vim.log.levels.WARN)
		return
	end

	local roots, leaf_id = read_session_tree(path)
	if #roots == 0 then
		notify("No tree entries found in this session.", vim.log.levels.WARN)
		return
	end

	if not valid_buf(state.tree_buf) then
		state.tree_buf = create_buffer("pi://tree", "text", false)
	end
	if not valid_buf(state.tree_preview_buf) then
		state.tree_preview_buf = create_buffer("pi://tree-preview", "markdown", false)
	end

	local lines = {
		"Pi session tree",
		"Filter: " .. (state.tree_filter_mode or "default"),
		"<CR> jump   S jump with summary   o cycle filter   r refresh   q close",
		"",
	}
	state.tree_nodes_by_line = {}
	render_tree_nodes(roots, leaf_id, lines, state.tree_nodes_by_line, "")
	set_buffer_lines(state.tree_buf, lines, false)

	local width = math.min(math.max(72, math.floor(vim.o.columns * 0.72)), vim.o.columns - 4)
	local outer_height = math.min(math.max(22, math.floor(vim.o.lines * 0.78)), vim.o.lines - 4)
	local top_height = math.max(8, math.floor((outer_height - 4) * 0.6))
	local preview_height = math.max(6, outer_height - top_height - 4)
	local row = math.max(1, math.floor((vim.o.lines - outer_height) / 2))
	local col = math.max(0, math.floor((vim.o.columns - width) / 2))

	close_tree_window()
	state.tree_win = vim.api.nvim_open_win(state.tree_buf, true, {
		relative = "editor",
		width = width,
		height = top_height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Pi Tree ",
		title_pos = "center",
	})
	state.tree_preview_win = vim.api.nvim_open_win(state.tree_preview_buf, false, {
		relative = "editor",
		width = width,
		height = preview_height,
		row = row + top_height + 2,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Preview ",
		title_pos = "center",
	})
	vim.api.nvim_set_option_value("wrap", false, { win = state.tree_win })
	vim.api.nvim_set_option_value("cursorline", true, { win = state.tree_win })
	vim.api.nvim_set_option_value("wrap", true, { win = state.tree_preview_win })
	vim.api.nvim_set_option_value("cursorline", false, { win = state.tree_preview_win })
	update_tree_preview()

	vim.keymap.set("n", "q", close_tree_window, { buffer = state.tree_buf, desc = "Close Pi tree" })
	vim.keymap.set("n", "<Esc>", close_tree_window, { buffer = state.tree_buf, desc = "Close Pi tree" })
	vim.keymap.set("n", "<CR>", function()
		jump_to_tree_node(false)
	end, { buffer = state.tree_buf, desc = "Jump to tree entry" })
	vim.keymap.set("n", "S", function()
		jump_to_tree_node(true)
	end, { buffer = state.tree_buf, desc = "Jump to tree entry with summary" })
	vim.keymap.set("n", "o", function()
		cycle_tree_filter_mode()
		M.show_tree()
	end, { buffer = state.tree_buf, desc = "Cycle Pi tree filter" })
	vim.keymap.set("n", "r", function()
		M.show_tree()
	end, { buffer = state.tree_buf, desc = "Refresh Pi tree" })
	vim.api.nvim_clear_autocmds({ group = tree_preview_augroup, buffer = state.tree_buf })
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = tree_preview_augroup,
		buffer = state.tree_buf,
		callback = update_tree_preview,
	})
end

function M.set_access_mode(mode)
	assert(is_access_mode(mode), "invalid access mode: " .. tostring(mode))
	state.access_mode = mode
	refresh_transcript_ui()
	if not (state.job and state.job > 0) then
		state.pending_access_mode = mode
		notify("Access mode will be applied when Pi starts: " .. mode)
		return
	end
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
		"- `<leader>/` pick a Pi slash command/template/skill and insert it into input.",
		"- `<CR>` on a `defer_task` tool result opens that deferred agent's artifacts.",
		"- `<leader>p` pick access mode.",
		"- `<leader>m` pick model.",
		"- `<leader>t` pick thinking level.",
		"- `<leader>s` pick session.",
		"- `<leader>h` pick a previous user message to fork or revert.",
		"- `<leader>T` open the session tree.",
		"- `<leader>n` new session.",
		"- `<leader>r` refresh transcript.",
		"- `<leader>R` rename session.",
		"- `<CR>` open the current tool output, or toggle a normal fold.",
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
				state.thinking_level = choice
				refresh_transcript_ui()
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

local function command_label(command)
	local prefix = "/" .. tostring(command.name or "")
	local source = command.source and (" [" .. command.source .. "]") or ""
	local description = command.description and command.description ~= "" and (" — " .. command.description) or ""
	return prefix .. source .. description
end

function M.pick_command()
	send({ type = "get_commands" }, function(event)
		local commands = event.data and event.data.commands or {}
		if #commands == 0 then
			notify("No Pi commands returned", vim.log.levels.WARN)
			return
		end
		table.sort(commands, function(a, b)
			return tostring(a.name or "") < tostring(b.name or "")
		end)
		vim.ui.select(commands, {
			prompt = "Pi command",
			format_item = command_label,
		}, function(choice)
			if not choice or not choice.name then
				return
			end
			set_input_text("/" .. tostring(choice.name) .. " ")
		end)
	end)
end

local function read_file_text(path)
	if not path or vim.fn.filereadable(path) ~= 1 then
		return nil
	end
	return table.concat(vim.fn.readfile(path), "\n")
end

open_defer_text = function(title, path, filetype)
	local text = read_file_text(path)
	if not text then
		notify("Could not read " .. tostring(path), vim.log.levels.WARN)
		return
	end
	if state.defer_win and vim.api.nvim_win_is_valid(state.defer_win) then
		vim.api.nvim_win_close(state.defer_win, true)
	end
	state.defer_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(state.defer_buf, "pi://defer/" .. vim.fn.fnamemodify(path, ":t"))
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = state.defer_buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.defer_buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = state.defer_buf })
	vim.api.nvim_set_option_value("filetype", filetype or "markdown", { buf = state.defer_buf })
	vim.api.nvim_buf_set_lines(state.defer_buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
	vim.api.nvim_set_option_value("modifiable", false, { buf = state.defer_buf })

	local width = math.min(math.max(72, math.floor(vim.o.columns * 0.82)), vim.o.columns - 4)
	local height = math.min(math.max(16, math.floor(vim.o.lines * 0.75)), vim.o.lines - 4)
	local row = math.max(1, math.floor((vim.o.lines - height) / 2))
	local col = math.max(0, math.floor((vim.o.columns - width) / 2))
	state.defer_win = vim.api.nvim_open_win(state.defer_buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " " .. title .. " ",
		title_pos = "left",
	})
	vim.api.nvim_set_option_value("wrap", true, { win = state.defer_win })
	vim.api.nvim_set_option_value("number", false, { win = state.defer_win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = state.defer_win })
	vim.keymap.set("n", "q", function()
		close_window(state.defer_win)
	end, { buffer = state.defer_buf, silent = true, desc = "Close defer output" })
	vim.keymap.set("n", "<Esc>", function()
		close_window(state.defer_win)
	end, { buffer = state.defer_buf, silent = true, desc = "Close defer output" })
	vim.keymap.set("n", "y", function()
		vim.fn.setreg("+", text)
		notify("Yanked defer output")
	end, { buffer = state.defer_buf, silent = true, desc = "Yank defer output" })
end

function M.reload()
	send({ type = "prompt", message = "/reload" }, function(event)
		if event.success then
			notify("Pi reload requested")
		else
			notify(event.error or "Could not reload Pi", vim.log.levels.ERROR)
		end
	end)
end

local function dirname(path)
	if not path or path == "" then
		return nil
	end
	return vim.fn.fnamemodify(path, ":h")
end

decode_session_record = function(line)
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

local function session_record_message_text(message)
	if type(message) ~= "table" then
		return nil
	end
	if type(message.content) == "string" then
		return message.content
	end
	if type(message.content) == "table" then
		local chunks = {}
		for _, item in ipairs(message.content) do
			if type(item) == "string" then
				table.insert(chunks, item)
			elseif type(item) == "table" and item.type == "text" and type(item.text) == "string" then
				table.insert(chunks, item.text)
			end
		end
		return table.concat(chunks, "")
	end
	return nil
end

local function fallback_session_title(text)
	text = vim.trim((text or ""):gsub("%s+", " "))
	text = text:gsub("^[Hh]ey[,:%s]+", "")
	text = text:gsub("^[Hh]i[,:%s]+", "")
	text = text:gsub("^[Hh]ello[,:%s]+", "")
	text = text:gsub("[%.%?!:;,]+$", "")
	if #text > 64 then
		text = vim.trim(text:sub(1, 61)) .. "..."
	end
	return text ~= "" and text or nil
end

local function looks_like_bad_model_title(title)
	if type(title) ~= "string" or title == "" then
		return false
	end
	local lower = title:lower()
	return lower:find("<tool_call>", 1, true)
		or lower:find("```", 1, true)
		or lower:match("^sure[%s!,.]")
		or lower:match("^sorry[%s!,.]")
		or lower:match("^i'm sorry")
		or lower:match("^im sorry")
		or lower:match("^i don't")
		or lower:match("^i cannot")
		or lower:match("^i can't")
		or lower:match("^i'll")
		or lower:match("^i will")
		or lower:match("^let me")
end

local function read_session_candidate(path)
	local candidate = {
		path = path,
		mtime = vim.fn.getftime(path),
		title = nil,
		cwd = nil,
	}
	local first_user_title = nil

	for _, line in ipairs(vim.fn.readfile(path)) do
		local record = decode_session_record(line)
		if record and record.type == "session" and type(record.cwd) == "string" and record.cwd ~= "" then
			candidate.cwd = record.cwd
		elseif record and record.type == "session_info" and type(record.name) == "string" and vim.trim(record.name) ~= "" then
			candidate.title = vim.trim(record.name)
		elseif record and not first_user_title and record.type == "message" and type(record.message) == "table" and record.message.role == "user" then
			first_user_title = fallback_session_title(session_record_message_text(record.message))
		end
	end

	if looks_like_bad_model_title(candidate.title) and first_user_title then
		candidate.title = first_user_title
	end

	return candidate
end

local function session_candidates()
	local dirs = {}
	local seen_dirs = {}
	local function add_dir(path)
		if not path or path == "" then
			return
		end
		path = vim.fn.expand(path)
		local resolved = vim.fn.resolve(path)
		if resolved == "" then
			resolved = path
		end
		if vim.fn.isdirectory(path) == 1 and not seen_dirs[resolved] then
			seen_dirs[resolved] = true
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

	local candidates = {}
	local seen_files = {}
	for _, dir in ipairs(dirs) do
		for _, path in ipairs(vim.fn.globpath(dir, "**/*.jsonl", false, true)) do
			local resolved = vim.fn.resolve(path)
			if resolved == "" then
				resolved = path
			end
			if not seen_files[resolved] then
				seen_files[resolved] = true
				table.insert(candidates, read_session_candidate(path))
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.mtime > b.mtime
	end)
	return candidates
end

local function session_item_label(candidate)
	local title = candidate.title or vim.fn.fnamemodify(candidate.path, ":t")
	local time = os.date("%Y-%m-%d %H:%M", candidate.mtime)
	if candidate.cwd and candidate.cwd ~= "" then
		return string.format("%s  pwd: %s  %s", title, vim.fn.fnamemodify(candidate.cwd, ":~"), time)
	end
	return string.format("%s  %s", title, time)
end

function M.pick_session()
	local candidates = session_candidates()
	if #candidates == 0 then
		notify("No session files found. Set PI_SESSION_DIR if your Pi sessions live elsewhere.", vim.log.levels.WARN)
		return
	end

	vim.ui.select(candidates, {
		prompt = "Pi session",
		format_item = session_item_label,
	}, function(choice)
		if not choice then
			return
		end
		if not (state.job and state.job > 0) then
			state.pending_session_file = choice.path
			state.session_file = choice.path
			state.session_name = choice.title
			state.tree_leaf_id = nil
			render_messages(load_session_messages_from_file(choice.path))
			notify("Selected session. Pi will attach to it when you send a message.")
			return
		end
		send({ type = "switch_session", sessionPath = choice.path }, function(event)
			if event.success and not (event.data and event.data.cancelled) then
				state.session_file = choice.path
				state.tree_leaf_id = nil
				send({ type = "get_state" }, function(state_event)
					if state_event.success and state_event.data then
						apply_session_state(state_event.data)
						M.refresh_session_stats()
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

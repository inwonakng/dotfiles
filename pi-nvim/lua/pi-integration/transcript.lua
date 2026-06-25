local M = {}

local padding_ns = vim.api.nvim_create_namespace("pi-nvim-transcript-padding")

local function yaml_value(value)
	if value == nil or value == "" then
		return "null"
	end
	local text = tostring(value):gsub("\\", "\\\\"):gsub('"', '\\"')
	return '"' .. text .. '"'
end

local function session_label(state)
	if not state.session_file or state.session_file == "" then
		return nil
	end
	return vim.fn.fnamemodify(state.session_file, ":t")
end

function M.metadata_lines(ctx)
	local state = ctx.state
	return {
		"---",
		"title: " .. yaml_value(state.session_name or "Pi Session"),
		"model: " .. yaml_value(state.model_id or ctx.config.model),
		"provider: " .. yaml_value(state.provider or ctx.config.provider),
		"thinking: " .. yaml_value(state.thinking_level),
		"access: " .. yaml_value(state.access_mode),
		"session: " .. yaml_value(session_label(state)),
		"cwd: " .. yaml_value(vim.fn.getcwd()),
		"last_updated: " .. yaml_value(state.last_updated),
		"---",
	}
end

function M.metadata_end(ctx)
	local state = ctx.state
	if not ctx.valid_buf(state.transcript_buf) then
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

function M.win_valid(ctx)
	local state = ctx.state
	return state.transcript_win
		and vim.api.nvim_win_is_valid(state.transcript_win)
		and ctx.valid_buf(state.transcript_buf)
		and vim.api.nvim_win_get_buf(state.transcript_win) == state.transcript_buf
end

function M.is_focused(ctx)
	return M.win_valid(ctx) and vim.api.nvim_get_current_win() == ctx.state.transcript_win
end

function M.preserve_focused_view(ctx, callback)
	local state = ctx.state
	if not M.is_focused(ctx) then
		callback()
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(state.transcript_win)
	local view = vim.fn.winsaveview()
	callback()

	if not M.win_valid(ctx) or not ctx.valid_buf(state.transcript_buf) then
		return
	end
	local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
	cursor[1] = math.min(cursor[1], line_count)
	vim.api.nvim_win_set_cursor(state.transcript_win, cursor)
	view.lnum = cursor[1]
	vim.fn.winrestview(view)
end

function M.update_metadata(ctx)
	local state = ctx.state
	if not ctx.valid_buf(state.transcript_buf) then
		return
	end
	M.preserve_focused_view(ctx, function()
		ctx.set_modifiable(state.transcript_buf, true)
		local end_line = M.metadata_end(ctx)
		local lines = M.metadata_lines(ctx)
		if end_line then
			vim.api.nvim_buf_set_lines(state.transcript_buf, 0, end_line, false, lines)
		else
			vim.api.nvim_buf_set_lines(state.transcript_buf, 0, 0, false, lines)
		end
		ctx.set_modifiable(state.transcript_buf, false)
	end)
end

function M.has_body(ctx)
	local state = ctx.state
	local end_line = M.metadata_end(ctx)
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

function M.render(ctx)
	local state = ctx.state
	if not ctx.valid_buf(state.transcript_buf) then
		return
	end
	if not M.win_valid(ctx) then
		return
	end

	local render_markdown = package.loaded["render-markdown"]
	if not (type(render_markdown) == "table" and type(render_markdown.render) == "function") then
		return
	end

	vim.schedule(function()
		if ctx.valid_buf(state.transcript_buf) and M.win_valid(ctx) then
			render_markdown.render({ buf = state.transcript_buf, win = state.transcript_win, event = "PiNvim" })
		end
	end)
end

function M.update_bottom_padding(ctx)
	local state = ctx.state
	if not ctx.valid_buf(state.transcript_buf) then
		return
	end

	vim.api.nvim_buf_clear_namespace(state.transcript_buf, padding_ns, 0, -1)
	local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
	if line_count < 1 then
		return
	end

	vim.api.nvim_buf_set_extmark(state.transcript_buf, padding_ns, line_count - 1, 0, {
		virt_lines = { { { " ", "Normal" } } },
		virt_lines_above = false,
		virt_lines_leftcol = true,
		priority = 1,
	})
end

function M.refresh_ui(ctx)
	ctx.state.last_updated = os.date("%Y-%m-%d %H:%M:%S %z")
	M.update_metadata(ctx)
	M.update_bottom_padding(ctx)
	ctx.update_transcript_statusline()
	M.render(ctx)
end

function M.schedule_refresh(ctx)
	local state = ctx.state
	if state.transcript_refresh_scheduled then
		return
	end
	state.transcript_refresh_scheduled = true
	vim.defer_fn(function()
		state.transcript_refresh_scheduled = false
		if ctx.valid_buf(state.transcript_buf) then
			M.refresh_ui(ctx)
		end
	end, 30)
end

function M.line_count(ctx)
	if not ctx.valid_buf(ctx.state.transcript_buf) then
		return 0
	end
	return vim.api.nvim_buf_line_count(ctx.state.transcript_buf)
end

function M.scroll_to_bottom_unless_focused(ctx)
	local state = ctx.state
	if M.win_valid(ctx) and not M.is_focused(ctx) then
		vim.api.nvim_win_set_cursor(state.transcript_win, { vim.api.nvim_buf_line_count(state.transcript_buf), 0 })
	end
end

function M.with_win(ctx, callback)
	if not M.win_valid(ctx) then
		return
	end
	vim.api.nvim_win_call(ctx.state.transcript_win, callback)
end

function M.append_lines(ctx, lines)
	local state = ctx.state
	if not ctx.valid_buf(state.transcript_buf) then
		return
	end
	state.pending_tool_separator = false
	if type(lines) == "string" then
		lines = vim.split(lines, "\n", { plain = true })
	end
	M.preserve_focused_view(ctx, function()
		ctx.set_modifiable(state.transcript_buf, true)
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
		ctx.set_modifiable(state.transcript_buf, false)
	end)
	M.update_bottom_padding(ctx)
	M.scroll_to_bottom_unless_focused(ctx)
	M.schedule_refresh(ctx)
end

function M.append_text(ctx, text)
	local state = ctx.state
	if not ctx.valid_buf(state.transcript_buf) or text == nil or text == "" then
		return
	end

	local parts = vim.split(text, "\n", { plain = true })
	M.preserve_focused_view(ctx, function()
		ctx.set_modifiable(state.transcript_buf, true)

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

		ctx.set_modifiable(state.transcript_buf, false)
	end)
	M.update_bottom_padding(ctx)
	M.scroll_to_bottom_unless_focused(ctx)
	M.schedule_refresh(ctx)
end

function M.append_message_header(ctx, role)
	if M.has_body(ctx) then
		M.append_lines(ctx, { "", "---", "", "## " .. role, "", "" })
	else
		M.append_lines(ctx, { "", "## " .. role, "", "" })
	end
end

function M.append_status(ctx, text)
	M.append_lines(ctx, { "> " .. text })
end

function M.remove_status(ctx, text)
	local state = ctx.state
	if not ctx.valid_buf(state.transcript_buf) then
		return
	end
	local target = "> " .. text
	M.preserve_focused_view(ctx, function()
		ctx.set_modifiable(state.transcript_buf, true)
		local lines = vim.api.nvim_buf_get_lines(state.transcript_buf, 0, -1, false)
		for index = #lines, 1, -1 do
			if lines[index] == target then
				vim.api.nvim_buf_set_lines(state.transcript_buf, index - 1, index, false, {})
			end
		end
		ctx.set_modifiable(state.transcript_buf, false)
	end)
	M.update_bottom_padding(ctx)
	M.schedule_refresh(ctx)
end

function M.scroll_to_bottom(ctx)
	local state = ctx.state
	if M.win_valid(ctx) and ctx.valid_buf(state.transcript_buf) then
		vim.api.nvim_win_set_cursor(state.transcript_win, { vim.api.nvim_buf_line_count(state.transcript_buf), 0 })
		M.with_win(ctx, function()
			vim.cmd("normal! zb")
		end)
	end
end

function M.delete_tool_folds(ctx)
	local state = ctx.state
	state.tool_folds = {}
	state.active_tool_fold = nil
	M.with_win(ctx, function()
		vim.cmd("normal! zE")
	end)
end

function M.apply_collected_tool_folds(ctx, folds)
	local state = ctx.state
	state.tool_folds = folds or {}
	state.active_tool_fold = nil
	M.with_win(ctx, function()
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

function M.remove_pending_tool_separator(ctx)
	local state = ctx.state
	if not state.pending_tool_separator or not ctx.valid_buf(state.transcript_buf) then
		return false
	end

	local removed = false
	M.preserve_focused_view(ctx, function()
		ctx.set_modifiable(state.transcript_buf, true)
		local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
		local last_line = vim.api.nvim_buf_get_lines(state.transcript_buf, line_count - 1, line_count, false)[1]
		if last_line == "" then
			vim.api.nvim_buf_set_lines(state.transcript_buf, line_count - 1, line_count, false, {})
			removed = true
		end
		ctx.set_modifiable(state.transcript_buf, false)
	end)
	state.pending_tool_separator = false
	return removed
end

function M.create_tool_fold(ctx, start_line, end_line, header_line, output_id)
	local state = ctx.state
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

	M.with_win(ctx, function()
		local cursor = vim.api.nvim_win_get_cursor(state.transcript_win)
		local view = vim.fn.winsaveview()
		local cursor_at_or_after_fold = cursor[1] >= fold_start
		vim.cmd(string.format("%d,%dfold", fold_start, end_line))
		vim.api.nvim_win_set_cursor(state.transcript_win, { fold_start, 0 })
		vim.cmd("normal! zc")
		local line_count = M.line_count(ctx)
		if cursor_at_or_after_fold then
			vim.api.nvim_win_set_cursor(state.transcript_win, { math.min(end_line + 1, line_count), 0 })
			vim.cmd("normal! zb")
		else
			vim.api.nvim_win_set_cursor(state.transcript_win, { math.min(cursor[1], line_count), cursor[2] })
			vim.fn.winrestview(view)
		end
	end)
end

function M.start_tool_fold(ctx, output_id)
	local line_count = M.line_count(ctx)
	ctx.state.active_tool_fold = {
		header_line = math.max(1, line_count - 1),
		start_line = line_count,
		output_id = output_id,
	}
end

function M.append_tool_fold_separator(ctx)
	local state = ctx.state
	-- append_lines() intentionally coalesces leading blank lines with an existing
	-- trailing blank. Here we specifically need one line outside the fold, even
	-- when the tool output itself ended with a blank line inside the folded range.
	M.preserve_focused_view(ctx, function()
		ctx.set_modifiable(state.transcript_buf, true)
		local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
		vim.api.nvim_buf_set_lines(state.transcript_buf, line_count, line_count, false, { "" })
		ctx.set_modifiable(state.transcript_buf, false)
	end)
	state.pending_tool_separator = true
	M.update_bottom_padding(ctx)
	M.schedule_refresh(ctx)
end

function M.finish_tool_fold(ctx)
	local state = ctx.state
	if not state.active_tool_fold then
		return
	end

	local tool_fold = state.active_tool_fold
	state.active_tool_fold = nil
	local end_line = M.line_count(ctx)
	M.append_tool_fold_separator(ctx)
	M.create_tool_fold(ctx, tool_fold.start_line, end_line, tool_fold.header_line, tool_fold.output_id)
end

function M.line_in_tool_fold(ctx, line)
	for _, tool_fold in ipairs(ctx.state.tool_folds) do
		local header_line = tool_fold.header_line or math.max(1, tool_fold.start_line - 1)
		if line >= header_line and line <= tool_fold.end_line then
			return tool_fold
		end
	end
	return nil
end

function M.toggle_tool_fold(ctx)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local tool_fold = M.line_in_tool_fold(ctx, cursor[1])
	if not tool_fold then
		return false
	end
	vim.api.nvim_win_set_cursor(0, { tool_fold.start_line, 0 })
	vim.cmd("normal! za")
	vim.api.nvim_win_set_cursor(0, cursor)
	return true
end

function M.stop_placeholder_timer(ctx)
	local state = ctx.state
	if state.placeholder_timer then
		state.placeholder_timer:stop()
		state.placeholder_timer:close()
		state.placeholder_timer = nil
	end
end

function M.set_placeholder_line(ctx, text)
	local state = ctx.state
	if not ctx.valid_buf(state.transcript_buf) or not state.placeholder_line then
		return
	end
	local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
	if state.placeholder_line < 1 or state.placeholder_line > line_count then
		return
	end
	M.preserve_focused_view(ctx, function()
		ctx.set_modifiable(state.transcript_buf, true)
		vim.api.nvim_buf_set_lines(state.transcript_buf, state.placeholder_line - 1, state.placeholder_line, false, { text })
		ctx.set_modifiable(state.transcript_buf, false)
	end)
	M.update_bottom_padding(ctx)
	M.schedule_refresh(ctx)
end

function M.clear_assistant_placeholder(ctx)
	local state = ctx.state
	M.stop_placeholder_timer(ctx)
	if not ctx.valid_buf(state.transcript_buf) or not state.placeholder_start_line or not state.placeholder_line then
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
	M.preserve_focused_view(ctx, function()
		ctx.set_modifiable(state.transcript_buf, true)
		vim.api.nvim_buf_set_lines(state.transcript_buf, start_line, end_line, false, {})
		ctx.set_modifiable(state.transcript_buf, false)
	end)
	state.placeholder_start_line = nil
	state.placeholder_line = nil
	M.update_bottom_padding(ctx)
	M.schedule_refresh(ctx)
end

function M.clear_assistant_placeholder_spinner(ctx)
	local state = ctx.state
	M.stop_placeholder_timer(ctx)
	if not ctx.valid_buf(state.transcript_buf) or not state.placeholder_line then
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
	M.preserve_focused_view(ctx, function()
		ctx.set_modifiable(state.transcript_buf, true)
		vim.api.nvim_buf_set_lines(state.transcript_buf, state.placeholder_line - 1, state.placeholder_line, false, {})
		ctx.set_modifiable(state.transcript_buf, false)
	end)
	state.placeholder_start_line = nil
	state.placeholder_line = nil
	M.update_bottom_padding(ctx)
	M.schedule_refresh(ctx)
end

function M.start_assistant_placeholder(ctx)
	local state = ctx.state
	M.clear_assistant_placeholder(ctx)
	local line_count = vim.api.nvim_buf_line_count(state.transcript_buf)
	local replacing_empty =
		line_count == 1 and vim.api.nvim_buf_get_lines(state.transcript_buf, 0, 1, false)[1] == ""
	local lines = M.has_body(ctx) and { "", "---", "", "## Assistant", "", "⠋" }
		or { "", "## Assistant", "", "⠋" }
	state.placeholder_start_line = replacing_empty and 1 or (line_count + 1)
	M.append_lines(ctx, lines)
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
		M.set_placeholder_line(ctx, frames[state.placeholder_tick])
	end))
end

function M.assistant_placeholder_active(ctx)
	return ctx.state.placeholder_start_line ~= nil and ctx.state.placeholder_line ~= nil
end

function M.render_error_message(ctx, title, message)
	M.clear_assistant_placeholder(ctx)
	ctx.state.error_rendered_for_active_run = true
	M.append_message_header(ctx, title)
	M.append_lines(ctx, { message })
end

return M

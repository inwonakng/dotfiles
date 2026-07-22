local floats = require("pi-integration.floats")
local guard = require("pi-integration.utils.guard")
local json = require("pi-integration.utils.json")

local M = {}

local tree_preview_augroup = vim.api.nvim_create_augroup("PiNvimTreePreview", { clear = true })
local tree_sender_ns = vim.api.nvim_create_namespace("pi-nvim-tree-senders")

local function decode_record(line)
	return json.decode_object(line)
end

local function record_text(ctx, record)
	if record.type == "message" and record.message then
		if record.message.role == "bashExecution" then
			return record.message.command or record.message.output or "bash execution"
		end
		return ctx.messages.extract_text(record.message) or ""
	elseif record.type == "branch_summary" then
		return record.summary or "branch summary"
	elseif record.type == "compaction" then
		return record.summary or "compaction summary"
	elseif record.type == "bashExecution" then
		return record.command or record.output or "bash execution"
	elseif record.type == "custom_message" then
		return ctx.messages.extract_text(record) or record.content or "custom message"
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

local function record_title(record)
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

local function message_has_visible_text(ctx, message)
	return vim.trim(ctx.messages.extract_text(message) or "") ~= ""
end

local function is_tool_record(ctx, record)
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
	if role == "assistant" and not message_has_visible_text(ctx, record.message) then
		return true
	end
	return false
end

local function record_visible(ctx, record, mode)
	mode = mode or ctx.state.tree_filter_mode or "default"
	if not ctx.config.tree_entry_types[record.type] then
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
		return not is_tool_record(ctx, record)
	end
	return not is_tool_record(ctx, record)
end

local function cycle_filter_mode(ctx)
	local modes = ctx.config.tree_filter_modes or { "default", "no-tools", "user-only", "all" }
	local current = ctx.state.tree_filter_mode or modes[1]
	for index, mode in ipairs(modes) do
		if mode == current then
			ctx.state.tree_filter_mode = modes[(index % #modes) + 1]
			return ctx.state.tree_filter_mode
		end
	end
	ctx.state.tree_filter_mode = modes[1]
	return ctx.state.tree_filter_mode
end

local function display_width(text)
	return vim.fn.strdisplaywidth(tostring(text or ""))
end

local function truncate_display(text, max_width)
	text = tostring(text or "")
	if not max_width or max_width <= 0 then
		return ""
	end
	if display_width(text) <= max_width then
		return text
	end

	local suffix = max_width >= 3 and "..." or string.rep(".", max_width)
	local target_width = max_width - display_width(suffix)
	if target_width <= 0 then
		return suffix
	end

	local low = 0
	local high = vim.fn.strcharlen(text)
	while low < high do
		local mid = math.ceil((low + high) / 2)
		if display_width(vim.fn.strcharpart(text, 0, mid)) <= target_width then
			low = mid
		else
			high = mid - 1
		end
	end
	return vim.fn.strcharpart(text, 0, low) .. suffix
end

local function compact_text(text, max_width)
	text = tostring(text or ""):gsub("%s+", " ")
	text = vim.trim(text)
	if text == "" then
		text = "(no text)"
	end
	return truncate_display(text, max_width or 96)
end

local function visible_parent(record, visible_by_id, by_id)
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

local function nearest_visible_id(id, visible_by_id, by_id)
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

local function read_session_tree(ctx, path)
	local records = {}
	local by_id = {}
	local visible_by_id = {}
	local last_id = nil
	if not path or vim.fn.filereadable(path) ~= 1 then
		return {}, nil
	end

	for _, line in ipairs(vim.fn.readfile(path)) do
		local record = decode_record(line)
		if record and record.id then
			by_id[record.id] = record
			last_id = record.id
			if record_visible(ctx, record, ctx.state.tree_filter_mode) then
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
		local parent_id = visible_parent(record, visible_by_id, by_id)
		if parent_id and nodes_by_id[parent_id] then
			table.insert(nodes_by_id[parent_id].children, node)
		else
			table.insert(roots, node)
		end
	end

	local leaf_id
	if ctx.state.tree_leaf_id ~= nil then
		leaf_id = nearest_visible_id(ctx.state.tree_leaf_id, visible_by_id, by_id)
	else
		leaf_id = nearest_visible_id(last_id, visible_by_id, by_id)
	end
	return roots, leaf_id
end

local function record_title_highlight(record)
	if record.type == "message" and record.message then
		local role = record.message.role
		if role == "user" then
			return "PiTreeUser"
		elseif role == "assistant" then
			return "PiTreeAssistant"
		elseif role == "toolResult" or role == "bashExecution" then
			return "PiTreeTool"
		end
		return "PiTreeMeta"
	elseif record.type == "bashExecution" then
		return "PiTreeTool"
	elseif record.type == "custom_message" then
		return "PiTreeCustom"
	end
	return "PiTreeMeta"
end

local function win_valid(win)
	return win and vim.api.nvim_win_is_valid(win)
end

local function tree_window_width(ctx)
	local state = ctx.state
	if win_valid(state.tree_win) then
		return vim.api.nvim_win_get_width(state.tree_win)
	end
	return state.tree_width or math.min(math.max(72, math.floor(vim.o.columns * 0.72)), vim.o.columns - 4)
end

local function render_node_line(ctx, node, leaf_id, lines, line_nodes, sender_highlights, line_prefix)
	local record = node.record
	local current = record.id == leaf_id
	local marker = current and "●" or "○"
	local title = record_title(record)
	local label_prefix = string.format("%s%s %s  ", line_prefix, marker, record.id)
	local heading = label_prefix .. title .. ": "
	local suffix = current and "  ← current" or ""
	local max_width = math.max(1, tree_window_width(ctx) - 1)
	local text_width = max_width - display_width(heading) - display_width(suffix)
	local label = heading .. compact_text(record_text(ctx, record), text_width) .. suffix
	label = truncate_display(label, max_width)
	table.insert(lines, label)
	line_nodes[#lines] = node
	sender_highlights[#lines] = {
		start_col = #label_prefix,
		end_col = #label_prefix + #title,
		hl_group = record_title_highlight(record),
	}
end

local function render_node(ctx, node, leaf_id, lines, line_nodes, sender_highlights, line_prefix, child_prefix)
	render_node_line(ctx, node, leaf_id, lines, line_nodes, sender_highlights, line_prefix)

	local child_count = #node.children
	if child_count == 0 then
		return
	end

	if child_count == 1 then
		-- Most session history is a single parent→child chain. Keep that
		-- continuation visually flat so long conversations do not drift right.
		render_node(ctx, node.children[1], leaf_id, lines, line_nodes, sender_highlights, child_prefix, child_prefix)
		return
	end

	-- Only spend horizontal space when there is an actual branch.
	for index, child in ipairs(node.children) do
		local is_last = index == child_count
		local connector = is_last and "└─ " or "├─ "
		local next_child_prefix = child_prefix .. (is_last and "   " or "│  ")
		render_node(ctx, child, leaf_id, lines, line_nodes, sender_highlights, child_prefix .. connector, next_child_prefix)
	end
end

local function render_nodes(ctx, nodes, leaf_id, lines, line_nodes, sender_highlights)
	for _, node in ipairs(nodes) do
		render_node(ctx, node, leaf_id, lines, line_nodes, sender_highlights, "", "")
	end
end

local function apply_sender_highlights(ctx)
	local state = ctx.state
	if not ctx.buffer.valid(state.tree_buf) then
		return
	end

	vim.api.nvim_buf_clear_namespace(state.tree_buf, tree_sender_ns, 0, -1)
	for line, highlight in pairs(state.tree_sender_highlights_by_line or {}) do
		vim.api.nvim_buf_set_extmark(state.tree_buf, tree_sender_ns, line - 1, highlight.start_col, {
			end_col = highlight.end_col,
			hl_group = highlight.hl_group,
			priority = 250,
		})
	end
end

local function focus_input_window(ctx)
	if win_valid(ctx.state.input_win) then
		vim.api.nvim_set_current_win(ctx.state.input_win)
	end
end

local function close_tree_window(ctx)
	local state = ctx.state
	floats.close_window(state.tree_win)
	floats.close_window(state.tree_preview_win)
	state.tree_win = nil
	state.tree_preview_win = nil
end

local function current_node(ctx)
	local win = vim.api.nvim_get_current_win()
	if ctx.buffer.valid(ctx.state.tree_buf) and vim.api.nvim_win_get_buf(win) ~= ctx.state.tree_buf and win_valid(ctx.state.tree_win) then
		win = ctx.state.tree_win
	end
	local cursor = vim.api.nvim_win_get_cursor(win)
	return ctx.state.tree_nodes_by_line[cursor[1]]
end

local function preview_lines(ctx, node)
	if not node or not node.record then
		return { "No tree entry selected." }
	end
	local record = node.record
	local lines = {
		string.format("%s  %s", record_title(record), record.id or ""),
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
		table.insert(lines, "model: " .. record_text(ctx, record))
	elseif record.type == "thinking_level_change" then
		table.insert(lines, "thinking: " .. record_text(ctx, record))
	end
	table.insert(lines, "")

	local text = record_text(ctx, record)
	if text == "" and record.type == "message" and record.message then
		text = vim.inspect(record.message.content or record.message)
	end
	if text == "" then
		text = vim.inspect(record)
	end
	vim.list_extend(lines, vim.split(tostring(text), "\n", { plain = true }))
	return lines
end

local function preview_entry_id(node)
	return node and node.record and node.record.id or nil
end

local function update_preview(ctx)
	local state = ctx.state
	if not ctx.buffer.valid(state.tree_preview_buf) then
		return
	end

	local node = current_node(ctx)
	local entry_id = preview_entry_id(node)
	local previous_entry_id = state.tree_preview_entry_id
	ctx.buffer.set_lines(state.tree_preview_buf, preview_lines(ctx, node), false)
	state.tree_preview_entry_id = entry_id

	if not win_valid(state.tree_preview_win) then
		return
	end

	local line = 1
	if entry_id == previous_entry_id then
		local ok, cursor = pcall(vim.api.nvim_win_get_cursor, state.tree_preview_win)
		if ok and cursor then
			line = math.min(math.max(cursor[1], 1), vim.api.nvim_buf_line_count(state.tree_preview_buf))
		end
	end
	pcall(vim.api.nvim_win_set_cursor, state.tree_preview_win, { line, 0 })
end

local function scroll_preview(ctx, direction)
	local state = ctx.state
	if not (win_valid(state.tree_preview_win) and ctx.buffer.valid(state.tree_preview_buf)) then
		return
	end
	if vim.api.nvim_win_get_buf(state.tree_preview_win) ~= state.tree_preview_buf then
		return
	end

	pcall(vim.api.nvim_win_call, state.tree_preview_win, function()
		local view = vim.fn.winsaveview()
		local line_count = math.max(1, vim.api.nvim_buf_line_count(state.tree_preview_buf))
		local height = math.max(1, vim.api.nvim_win_get_height(state.tree_preview_win))
		local max_topline = math.max(1, line_count - height + 1)
		local page = math.max(1, height - 1)
		local target_topline = math.min(math.max((view.topline or 1) + (direction * page), 1), max_topline)
		view.topline = target_topline
		view.lnum = target_topline
		view.col = 0
		view.curswant = 0
		vim.fn.winrestview(view)
	end)
end

local function selected_tree_position(ctx)
	local state = ctx.state
	local win = win_valid(state.tree_win) and state.tree_win or vim.api.nvim_get_current_win()
	local ok, cursor = pcall(vim.api.nvim_win_get_cursor, win)
	local row = ok and cursor[1] or 1
	local node = (state.tree_nodes_by_line or {})[row]
	return {
		row = row,
		entry_id = node and node.record and node.record.id or nil,
		parent_id = node and node.record and node.record.parentId or nil,
	}
end

local function save_tree_view(ctx)
	if not win_valid(ctx.state.tree_win) then
		return nil
	end
	local ok, view = pcall(vim.api.nvim_win_call, ctx.state.tree_win, function()
		return vim.fn.winsaveview()
	end)
	return ok and view or nil
end

local function find_tree_line_by_id(ctx, entry_id)
	if not entry_id then
		return nil
	end
	for line, node in pairs(ctx.state.tree_nodes_by_line or {}) do
		if node and node.record and node.record.id == entry_id then
			return line
		end
	end
	return nil
end

local function render_tree_buffer(ctx, opts)
	opts = opts or {}
	local state = ctx.state
	local path = state.session_file or state.pending_session_file
	if not path or path == "" then
		ctx.ui.notify("No Pi session selected yet.", vim.log.levels.WARN)
		return false
	end

	local roots, leaf_id = read_session_tree(ctx, path)
	if #roots == 0 and not opts.allow_empty then
		ctx.ui.notify("No tree entries found in this session.", vim.log.levels.WARN)
		return false
	end

	if not ctx.buffer.valid(state.tree_buf) then
		state.tree_buf = ctx.buffer.create("pi://tree", "text", false)
	end
	if not ctx.buffer.valid(state.tree_preview_buf) then
		state.tree_preview_buf = ctx.buffer.create("pi://tree-preview", "markdown", false)
	end

	local lines = {
		"Pi session tree",
		"Filter: " .. (state.tree_filter_mode or "default") .. "    Layout: compressed",
		"<CR> jump   S jump with summary   <C-f>/<C-b> scroll preview",
		"d delete subtree   o cycle filter   r refresh   q close",
		"",
	}
	state.tree_nodes_by_line = {}
	state.tree_sender_highlights_by_line = {}
	if #roots == 0 then
		table.insert(lines, "No tree entries found in this session.")
	else
		render_nodes(ctx, roots, leaf_id, lines, state.tree_nodes_by_line, state.tree_sender_highlights_by_line)
	end
	ctx.buffer.set_lines(state.tree_buf, lines, false)
	apply_sender_highlights(ctx)
	return true
end

local function restore_tree_view(ctx, opts)
	opts = opts or {}
	local state = ctx.state
	if not win_valid(state.tree_win) or not ctx.buffer.valid(state.tree_buf) then
		return
	end

	local line = find_tree_line_by_id(ctx, opts.entry_id) or find_tree_line_by_id(ctx, opts.parent_id) or opts.row or 1
	local max_line = math.max(1, vim.api.nvim_buf_line_count(state.tree_buf))
	line = math.min(math.max(line, 1), max_line)

	pcall(vim.api.nvim_win_call, state.tree_win, function()
		if opts.view then
			local view = {}
			for key, value in pairs(opts.view) do
				view[key] = value
			end
			view.lnum = line
			view.col = 0
			view.curswant = 0
			vim.fn.winrestview(view)
		else
			vim.api.nvim_win_set_cursor(state.tree_win, { line, 0 })
		end
	end)
end

local function refresh_tree_in_place(ctx, opts)
	if not render_tree_buffer(ctx, { allow_empty = true }) then
		return false
	end
	restore_tree_view(ctx, opts)
	update_preview(ctx)
	return true
end

local function selected_session_path(ctx)
	local path = ctx.state.session_file or ctx.state.pending_session_file
	if not path or path == "" then
		ctx.ui.notify("No Pi session selected yet.", vim.log.levels.WARN)
		return nil
	end
	return path
end

local function jump_to_node(ctx, summarize)
	local node = current_node(ctx)
	if not node then
		return
	end
	if not guard.if_not_active(ctx, "changing history") then
		return
	end
	local entry_id = node.record.id
	if not selected_session_path(ctx) then
		return
	end
	close_tree_window(ctx)

	local message = "/pi-tree-jump " .. entry_id .. (summarize and " --summary" or "")
	ctx.rpc.send({ type = "prompt", message = message }, function(event)
		if not event.success then
			ctx.ui.notify(event.error or "Could not navigate session tree", vim.log.levels.ERROR)
			return
		end
		ctx.rpc.send({ type = "get_state" }, function(state_event)
			if state_event.success and state_event.data then
				ctx.session.apply_state(state_event.data)
			end
			ctx.actions.refresh_messages()
			focus_input_window(ctx)
		end)
	end)
end

local function delete_node(ctx)
	local node = current_node(ctx)
	if not node then
		return
	end
	if not guard.if_not_active(ctx, "deleting history") then
		return
	end
	if not selected_session_path(ctx) then
		return
	end

	local position = selected_tree_position(ctx)
	position.view = save_tree_view(ctx)
	local entry_id = node.record.id

	ctx.rpc.send({ type = "prompt", message = "/pi-tree-delete " .. entry_id .. " --yes" }, function(event)
		if not event.success then
			ctx.ui.notify(event.error or "Could not delete session tree entry", vim.log.levels.ERROR)
			return
		end
		ctx.rpc.send({ type = "get_state" }, function(state_event)
			if state_event.success and state_event.data then
				ctx.session.apply_state(state_event.data)
			end
			ctx.actions.refresh_messages()
			if win_valid(ctx.state.tree_win) then
				refresh_tree_in_place(ctx, position)
				vim.api.nvim_set_current_win(ctx.state.tree_win)
			else
				focus_input_window(ctx)
			end
		end)
	end)
end

function M.show(ctx)
	local state = ctx.state
	if win_valid(state.tree_win) then
		local position = selected_tree_position(ctx)
		position.view = save_tree_view(ctx)
		refresh_tree_in_place(ctx, position)
		vim.api.nvim_set_current_win(state.tree_win)
		return
	end

	local width = math.min(math.max(72, math.floor(vim.o.columns * 0.72)), vim.o.columns - 4)
	state.tree_width = width
	if not render_tree_buffer(ctx) then
		return
	end

	local outer_height = math.min(math.max(22, math.floor(vim.o.lines * 0.78)), vim.o.lines - 4)
	local top_height = math.max(8, math.floor((outer_height - 4) * 0.6))
	local preview_height = math.max(6, outer_height - top_height - 4)
	local row = math.max(1, math.floor((vim.o.lines - outer_height) / 2))
	local col = math.max(0, math.floor((vim.o.columns - width) / 2))

	close_tree_window(ctx)
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
	update_preview(ctx)
	floats.close_on_win_leave(state.tree_buf, function()
		close_tree_window(ctx)
	end, { win = state.tree_win })

	vim.keymap.set("n", "q", function()
		close_tree_window(ctx)
	end, { buffer = state.tree_buf, desc = "Close Pi tree" })
	vim.keymap.set("n", "<Esc>", function()
		close_tree_window(ctx)
	end, { buffer = state.tree_buf, desc = "Close Pi tree" })
	vim.keymap.set("n", "<CR>", function()
		jump_to_node(ctx, false)
	end, { buffer = state.tree_buf, desc = "Jump to tree entry" })
	vim.keymap.set("n", "S", function()
		jump_to_node(ctx, true)
	end, { buffer = state.tree_buf, desc = "Jump to tree entry with summary" })
	vim.keymap.set("n", "<C-f>", function()
		scroll_preview(ctx, 1)
	end, { buffer = state.tree_buf, desc = "Scroll Pi tree preview down" })
	vim.keymap.set("n", "<C-b>", function()
		scroll_preview(ctx, -1)
	end, { buffer = state.tree_buf, desc = "Scroll Pi tree preview up" })
	vim.keymap.set("n", "d", function()
		delete_node(ctx)
	end, { buffer = state.tree_buf, desc = "Delete Pi tree entry subtree" })
	vim.keymap.set("n", "o", function()
		local position = selected_tree_position(ctx)
		position.view = save_tree_view(ctx)
		cycle_filter_mode(ctx)
		refresh_tree_in_place(ctx, position)
	end, { buffer = state.tree_buf, desc = "Cycle Pi tree filter" })
	vim.keymap.set("n", "r", function()
		local position = selected_tree_position(ctx)
		position.view = save_tree_view(ctx)
		refresh_tree_in_place(ctx, position)
	end, { buffer = state.tree_buf, desc = "Refresh Pi tree" })
	vim.api.nvim_clear_autocmds({ group = tree_preview_augroup, buffer = state.tree_buf })
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = tree_preview_augroup,
		buffer = state.tree_buf,
		callback = function()
			update_preview(ctx)
		end,
	})
end

return M

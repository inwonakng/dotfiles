local floats = require("pi-integration.floats")
local json = require("pi-integration.utils.json")
local message_utils = require("pi-integration.utils.message")

local M = {}

local path_from_args = message_utils.path_from_args
local tool_call_id = message_utils.tool_call_id
local tool_call_name = message_utils.tool_call_name
local tool_call_arguments = message_utils.tool_call_arguments

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

local function diff_text_for_line_stats(text)
	if type(text) ~= "string" or text == "" or text:sub(-1) == "\n" then
		return text or ""
	end
	return text .. "\n"
end

local function edit_change_stats(args)
	if type(args) ~= "table" or type(args.edits) ~= "table" then
		return nil
	end
	local stats = {
		additions = 0,
		removals = 0,
		blocks = 0,
	}
	for _, edit in ipairs(args.edits) do
		if type(edit) ~= "table" or type(edit.oldText) ~= "string" or type(edit.newText) ~= "string" then
			return nil
		end
		stats.blocks = stats.blocks + 1
		if edit.oldText ~= edit.newText then
			local ok, hunks = pcall(vim.diff, diff_text_for_line_stats(edit.oldText), diff_text_for_line_stats(edit.newText), {
				result_type = "indices",
			})
			if ok and type(hunks) == "table" then
				for _, hunk in ipairs(hunks) do
					if type(hunk) == "table" then
						stats.removals = stats.removals + (tonumber(hunk[2]) or 0)
						stats.additions = stats.additions + (tonumber(hunk[4]) or 0)
					end
				end
			else
				stats.removals = stats.removals + line_count_text(edit.oldText)
				stats.additions = stats.additions + line_count_text(edit.newText)
			end
		end
	end
	return stats
end

local function edit_change_label(args)
	local stats = edit_change_stats(args)
	if not stats then
		return nil
	end
	local block_label = stats.blocks == 1 and "1 block" or (tostring(stats.blocks) .. " blocks")
	return "+" .. tostring(stats.additions) .. "/-" .. tostring(stats.removals) .. " · " .. block_label
end

local function looks_like_json(text)
	if type(text) ~= "string" then
		return false
	end
	local trimmed = vim.trim(text)
	if not (trimmed:sub(1, 1) == "{" or trimmed:sub(1, 1) == "[") then
		return false
	end
	return json.decode(trimmed) ~= nil
end

local function infer_filetype(tool_name, text)
	if looks_like_json(text) then
		return "json"
	end
	if tool_name == "edit" then
		return "diff"
	end
	return "text"
end

local function output_path(output)
	local args = type(output) == "table" and type(output.args) == "table" and output.args or nil
	local path = path_from_args(args)
	if type(path) == "string" and path ~= "" then
		return path
	end
	return nil
end

local function filetype_from_path(path)
	if type(path) ~= "string" or path == "" then
		return "text"
	end
	local ok, filetype = pcall(vim.filetype.match, { filename = path })
	if ok and type(filetype) == "string" and filetype ~= "" then
		return filetype
	end
	return "text"
end

local function normalize_lines(text)
	if type(text) ~= "string" or text == "" then
		return {}
	end
	text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
	local lines = vim.split(text, "\n", { plain = true })
	if lines[#lines] == "" then
		table.remove(lines)
	end
	return lines
end

local function edit_args_to_before_after(args)
	if type(args) ~= "table" then
		return nil, nil, "missing edit arguments"
	end
	local path = path_from_args(args)
	local edits = args.edits
	if type(path) ~= "string" or path == "" then
		return nil, nil, "missing edit path"
	end
	if type(edits) ~= "table" then
		return nil, nil, "missing edit replacements"
	end
	local before_parts = {}
	local after_parts = {}
	for _, edit in ipairs(edits) do
		if type(edit) ~= "table" or type(edit.oldText) ~= "string" or type(edit.newText) ~= "string" then
			return nil, nil, "invalid edit replacement"
		end
		table.insert(before_parts, edit.oldText)
		table.insert(after_parts, edit.newText)
	end
	return table.concat(before_parts, "\n"), table.concat(after_parts, "\n"), nil
end

local function compact_text(text)
	if type(text) ~= "string" then
		return ""
	end
	return (text:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\n", " ⏎ "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function truncate_text(text, max_len)
	text = compact_text(text)
	max_len = max_len or 120
	if #text <= max_len then
		return text
	end
	return text:sub(1, math.max(1, max_len - 1)) .. "…"
end

local function short_run_id(id)
	if type(id) ~= "string" or id == "" then
		return nil
	end
	return id:match("([^-]+)$") or id
end

local function run_id(run)
	if type(run) ~= "table" then
		return nil
	end
	return run.runId or run.id
end

local function is_spawn_output_name(name)
	return name == "spawn" or name == "spawn_control"
end

local function merge_details(old_details, new_details)
	if type(old_details) ~= "table" then
		return new_details
	end
	if type(new_details) ~= "table" then
		return old_details
	end
	local merged = {}
	for key, value in pairs(old_details) do
		merged[key] = value
	end
	for key, value in pairs(new_details) do
		merged[key] = value
	end
	return merged
end

local function markdown_code_span(text)
	text = tostring(text or "")
	local longest = 0
	for run in text:gmatch("`+") do
		longest = math.max(longest, #run)
	end
	local ticks = string.rep("`", longest + 1)
	if text:sub(1, 1) == "`" or text:sub(-1) == "`" then
		return ticks .. " " .. text .. " " .. ticks
	end
	return ticks .. text .. ticks
end

local function command_preview(command)
	local compact = compact_text(command)
	local words = {}
	local truncated = false
	for word in compact:gmatch("%S+") do
		if #words == 3 then
			truncated = true
			break
		end
		table.insert(words, word)
	end
	local preview = #words > 0 and table.concat(words, " ") or "command"
	return truncated and (preview .. " ...") or preview
end

local function display_for_call(name, args)
	if name == "bash" and type(args) == "table" and type(args.command) == "string" and args.command ~= "" then
		return {
			kind = "bash",
			command = args.command,
		}
	end
	if (name == "read" or name == "edit" or name == "write") and type(args) == "table" then
		local path = path_from_args(args)
		if type(path) == "string" and path ~= "" then
			return {
				kind = "file",
				path = path,
			}
		end
	end
	return nil
end

local function path_from_artifact_line(text, label)
	if type(text) ~= "string" then
		return nil
	end
	return text:match("%- " .. label .. ": ([^\n]+)")
end

local function artifact_path_value(value)
	return type(value) == "string" and value ~= "" and value or nil
end

local function spawn_artifacts(tool_name, text, details)
	if tool_name ~= "spawn" and tool_name ~= "spawn_control" then
		return nil
	end
	details = type(details) == "table" and details or {}
	local worktree = type(details.worktree) == "table" and details.worktree or nil
	local artifacts = {
		brief = artifact_path_value(details.briefPath) or path_from_artifact_line(text, "Brief"),
		result = artifact_path_value(details.resultPath) or path_from_artifact_line(text, "Result"),
		transcript = artifact_path_value(details.transcriptPath) or path_from_artifact_line(text, "Transcript"),
		status = artifact_path_value(details.statusPath) or path_from_artifact_line(text, "Status"),
		agent_prompt = artifact_path_value(details.agentPromptPath) or path_from_artifact_line(text, "Subagent prompt"),
		patch = artifact_path_value(details.patchPath) or artifact_path_value(worktree and worktree.patchPath) or path_from_artifact_line(text, "Patch"),
	}
	if artifacts.brief or artifacts.result or artifacts.transcript or artifacts.status or artifacts.agent_prompt or artifacts.patch then
		return artifacts
	end
	return nil
end

local function sanitize_buf_name_part(value)
	return tostring(value or "tool"):gsub("[^%w%._%-]+", "-")
end

local function read_file_text(path)
	if not path or vim.fn.filereadable(path) ~= 1 then
		return nil
	end
	return table.concat(vim.fn.readfile(path), "\n")
end

local function open_spawn_text(ctx, title, path, filetype)
	local state = ctx.state
	local text = read_file_text(path)
	if not text then
		ctx.ui.notify("Could not read " .. tostring(path), vim.log.levels.WARN)
		return
	end
	floats.close_window(state.spawn_win)
	state.spawn_win = nil
	state.spawn_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(state.spawn_buf, "pi://spawn/" .. vim.fn.fnamemodify(path, ":t"))
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = state.spawn_buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.spawn_buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = state.spawn_buf })
	vim.api.nvim_set_option_value("filetype", filetype or "markdown", { buf = state.spawn_buf })
	vim.api.nvim_buf_set_lines(state.spawn_buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
	vim.api.nvim_set_option_value("modifiable", false, { buf = state.spawn_buf })

	local width = math.min(math.max(72, math.floor(vim.o.columns * 0.82)), vim.o.columns - 4)
	local height = math.min(math.max(16, math.floor(vim.o.lines * 0.75)), vim.o.lines - 4)
	local row = math.max(1, math.floor((vim.o.lines - height) / 2))
	local col = math.max(0, math.floor((vim.o.columns - width) / 2))
	state.spawn_win = vim.api.nvim_open_win(state.spawn_buf, true, {
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
	vim.api.nvim_set_option_value("wrap", true, { win = state.spawn_win })
	vim.api.nvim_set_option_value("number", false, { win = state.spawn_win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = state.spawn_win })
	local close_spawn_win = function()
		floats.close_window(state.spawn_win)
		state.spawn_win = nil
	end
	floats.close_on_win_leave(state.spawn_buf, close_spawn_win, { win = state.spawn_win, parent = ctx.window.parent })
	vim.keymap.set("n", "q", close_spawn_win, { buffer = state.spawn_buf, silent = true, desc = "Close spawn output" })
	vim.keymap.set("n", "<Esc>", close_spawn_win, { buffer = state.spawn_buf, silent = true, desc = "Close spawn output" })
	vim.keymap.set("n", "y", function()
		vim.fn.setreg("+", text)
		ctx.ui.notify("Yanked spawn output")
	end, { buffer = state.spawn_buf, silent = true, desc = "Yank spawn output" })
end

local function is_todo_tool_name(name)
	return name == "todowrite" or name == "todo_write"
end

local function open_spawn_artifacts(ctx, output)
	if not output.spawn then
		return false
	end
	local choices = {}
	local function add(label, path, filetype)
		if type(path) == "string" and path ~= "" then
			table.insert(choices, { label = label, path = path, filetype = filetype })
		end
	end
	add("result", output.spawn.result, "markdown")
	add("transcript", output.spawn.transcript, "json")
	add("brief", output.spawn.brief, "markdown")
	add("status", output.spawn.status, "json")
	add("subagent prompt", output.spawn.agent_prompt, "markdown")
	add("patch", output.spawn.patch, "diff")
	if #choices == 0 then
		ctx.ui.notify("No spawn artifacts found for this tool call", vim.log.levels.WARN)
		return true
	end
	vim.ui.select(choices, {
		prompt = "Open spawn artifact",
		format_item = function(item)
			return item.label .. "  " .. item.path
		end,
	}, function(choice)
		if choice then
			if choice.label == "transcript" then
				require("pi-integration.spawn-transcript").open(ctx, choice.path, "Spawn transcript")
			else
				open_spawn_text(ctx, "Spawn " .. choice.label, choice.path, choice.filetype)
			end
		end
	end)
	return true
end

function M.reset(state)
	state.tool_outputs = {}
	state.next_tool_output_id = 0
	state.tool_calls = {}
	state.live_tool_output_by_call = {}
	state.live_tool_lines = {}
	state.spawn_run_output_by_id = {}
	state.spawn_run_lines = {}
	state.todo_tool_output_id = nil
	state.todo_tool_line = nil
end

function M.record_calls(state, message)
	state.tool_calls = state.tool_calls or {}
	if type(message) ~= "table" or type(message.content) ~= "table" then
		return
	end
	for _, item in ipairs(message.content) do
		if type(item) == "table" and (item.type == "toolCall" or item.type == "tool_call") then
			local id = tool_call_id(item)
			local name = tool_call_name(item)
			if id and name then
				local args = tool_call_arguments(item)
				local call = state.tool_calls[id] or {}
				call.name = name
				call.args = args or call.args
				call.display = display_for_call(name, call.args) or call.display
				state.tool_calls[id] = call
			end
		end
	end
end

function M.display_for_result(state, message)
	if type(message) ~= "table" then
		return nil
	end
	local id = message.toolCallId or message.tool_call_id or message.id
	local call = id and state.tool_calls and state.tool_calls[id]
	return call and call.display or nil
end

function M.record_execution_call(state, tool_name, tool_call_id, args)
	if not tool_call_id then
		return
	end
	state.tool_calls = state.tool_calls or {}
	local call = state.tool_calls[tool_call_id] or {}
	call.name = tool_name or call.name
	call.args = type(args) == "table" and args or call.args
	call.display = display_for_call(call.name, call.args) or call.display
	state.tool_calls[tool_call_id] = call
end

local function call_args_for_id(state, tool_call_id)
	local call = tool_call_id and state.tool_calls and state.tool_calls[tool_call_id]
	return call and call.args or nil
end

local function rendered_output(output)
	if not output then
		return "", "text"
	end
	if output.name == "edit" then
		local details = type(output.details) == "table" and output.details or {}
		if type(details.patch) == "string" and details.patch ~= "" then
			return details.patch, "diff"
		end
		if type(details.diff) == "string" and details.diff ~= "" then
			return details.diff, "diff"
		end
	elseif output.name == "write" then
		local args = type(output.args) == "table" and output.args or {}
		if type(args.content) == "string" then
			return args.content, filetype_from_path(path_from_args(args))
		end
	end
	local text = output.text or ""
	return text, output.filetype or infer_filetype(output.name, text)
end

local function set_diff_window_options(win)
	vim.api.nvim_set_option_value("wrap", false, { win = win })
	vim.api.nvim_set_option_value("number", true, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
	vim.api.nvim_set_option_value("scrollbind", true, { win = win })
	vim.api.nvim_set_option_value("cursorbind", true, { win = win })
	vim.api.nvim_set_option_value("foldmethod", "diff", { win = win })
	vim.api.nvim_set_option_value("foldenable", true, { win = win })
	vim.api.nvim_set_option_value("foldlevel", 0, { win = win })
end

local function set_scratch_buffer(buf, name, filetype, lines)
	vim.api.nvim_buf_set_name(buf, name)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", filetype or "text", { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

local function open_edit_diff_float(ctx, output)
	local args = type(output.args) == "table" and output.args or {}
	local path = path_from_args(args)
	if type(path) ~= "string" or path == "" then
		return false
	end
	local before, after = edit_args_to_before_after(args)
	if not before then
		return false
	end

	local width = math.max(80, math.floor(vim.o.columns * 0.9))
	local height = math.max(12, math.floor(vim.o.lines * 0.8))
	width = math.min(width, math.max(2, vim.o.columns - 4))
	height = math.min(height, math.max(1, vim.o.lines - 4))
	local left_width = math.max(1, math.floor((width - 1) / 2))
	local right_width = math.max(1, width - left_width - 1)
	local row = math.floor((vim.o.lines - height) / 2)
	local left_col = math.floor((vim.o.columns - width) / 2)
	local right_col = left_col + left_width + 1
	local filetype = filetype_from_path(path)

	local left_buf = vim.api.nvim_create_buf(false, true)
	local right_buf = vim.api.nvim_create_buf(false, true)
	set_scratch_buffer(left_buf, "pi://tool/" .. tostring(output.tool_call_id or "edit") .. "/before", filetype, normalize_lines(before))
	set_scratch_buffer(right_buf, "pi://tool/" .. tostring(output.tool_call_id or "edit") .. "/after", filetype, normalize_lines(after))

	local left_win = vim.api.nvim_open_win(left_buf, true, {
		relative = "editor",
		width = left_width,
		height = height,
		row = row,
		col = left_col,
		style = "minimal",
		border = "rounded",
		title = " Before: " .. vim.fn.fnamemodify(path, ":t") .. " ",
		title_pos = "left",
	})
	local right_win = vim.api.nvim_open_win(right_buf, false, {
		relative = "editor",
		width = right_width,
		height = height,
		row = row,
		col = right_col,
		style = "minimal",
		border = "rounded",
		title = " After: " .. vim.fn.fnamemodify(path, ":t") .. " ",
		title_pos = "left",
	})

	set_diff_window_options(left_win)
	set_diff_window_options(right_win)
	vim.api.nvim_set_current_win(left_win)
	vim.cmd("diffthis")
	vim.api.nvim_set_current_win(right_win)
	vim.cmd("diffthis")

	local closed = false
	local close_diff = function()
		if closed then
			return
		end
		closed = true
		for _, win in ipairs({ left_win, right_win }) do
			if win and vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_call(win, function()
					pcall(vim.cmd, "diffoff")
				end)
				floats.close_window(win)
			end
		end
	end
	floats.close_on_win_leave(left_buf, close_diff, { win = left_win, parent = ctx.window.parent })
	floats.close_on_win_leave(right_buf, close_diff, { win = right_win, parent = left_win })
	for _, buf in ipairs({ left_buf, right_buf }) do
		vim.keymap.set("n", "q", close_diff, { buffer = buf, silent = true, desc = "Close edit diff" })
		vim.keymap.set("n", "<Esc>", close_diff, { buffer = buf, silent = true, desc = "Close edit diff" })
		vim.keymap.set("n", "y", function()
			local rendered_text = rendered_output(output)
			vim.fn.setreg("+", rendered_text or "")
			ctx.ui.notify("Yanked edit patch")
		end, { buffer = buf, silent = true, desc = "Yank edit patch" })
	end
	return true
end

function M.store(state, tool_name, text, filetype, details, display, tool_call_id)
	state.next_tool_output_id = state.next_tool_output_id + 1
	local id = state.next_tool_output_id
	local call = tool_call_id and state.tool_calls and state.tool_calls[tool_call_id]
	state.tool_outputs[id] = {
		name = tool_name or "tool",
		text = text or "",
		filetype = filetype or infer_filetype(tool_name, text),
		details = details,
		display = display or (call and call.display),
		spawn = spawn_artifacts(tool_name, text, details),
		tool_call_id = tool_call_id,
		args = call and call.args or nil,
	}
	if tool_call_id then
		state.live_tool_output_by_call = state.live_tool_output_by_call or {}
		state.live_tool_output_by_call[tool_call_id] = id
	end
	if is_spawn_output_name(tool_name) then
		M.bind_spawn_run(state, details, id)
	end
	return id
end

function M.store_or_update_live(state, tool_name, tool_call_id, text, filetype, details, display)
	state.live_tool_output_by_call = state.live_tool_output_by_call or {}
	local output_id = tool_call_id and state.live_tool_output_by_call[tool_call_id]
	if output_id and state.tool_outputs[output_id] then
		local output = state.tool_outputs[output_id]
		output.name = tool_name or output.name or "tool"
		output.text = text or output.text or ""
		output.filetype = filetype or output.filetype or infer_filetype(tool_name, text)
		output.details = merge_details(output.details, details)
		output.display = display or output.display
		output.args = call_args_for_id(state, tool_call_id) or output.args
		output.spawn = spawn_artifacts(output.name, output.text, output.details)
		if is_spawn_output_name(output.name) then
			M.bind_spawn_run(state, output.details, output_id)
		end
		return output_id, true
	end
	return M.store(state, tool_name, text, filetype, details, display, tool_call_id), false
end

function M.bind_spawn_run(state, run, output_id, line)
	local id = run_id(run)
	if type(id) ~= "string" or id == "" then
		return false
	end
	if output_id then
		state.spawn_run_output_by_id = state.spawn_run_output_by_id or {}
		state.spawn_run_output_by_id[id] = output_id
	end
	if line then
		state.spawn_run_lines = state.spawn_run_lines or {}
		state.spawn_run_lines[id] = line
	end
	return true
end

function M.store_or_update_spawn_run(state, run, text)
	if type(run) ~= "table" then
		return nil, false
	end
	local id = run_id(run)
	if type(id) ~= "string" or id == "" then
		return nil, false
	end
	state.spawn_run_output_by_id = state.spawn_run_output_by_id or {}
	local output_id = state.spawn_run_output_by_id[id]
	local output_text = text or run.progress or ""
	if output_id and state.tool_outputs[output_id] then
		local output = state.tool_outputs[output_id]
		output.name = output.name == "spawn" and "spawn" or "spawn_control"
		output.text = output_text
		output.filetype = infer_filetype(output.name, output_text)
		output.details = merge_details(output.details, run)
		output.display = nil
		output.spawn = spawn_artifacts(output.name, output.text, output.details)
		M.bind_spawn_run(state, output.details, output_id)
		return output_id, true
	end
	return nil, false
end

function M.live_output_id(state, tool_call_id)
	return tool_call_id and state.live_tool_output_by_call and state.live_tool_output_by_call[tool_call_id] or nil
end

function M.summary_lines(state, output_id)
	local output = state.tool_outputs[output_id]
	if not output then
		return { "> Tool output unavailable." }
	end
	local rendered_text = rendered_output(output)
	local lines = line_count_text(rendered_text)
	local line_label = lines == 1 and "1 line" or (tostring(lines) .. " lines")
	local label = "Tool: " .. tostring(output.name or "tool")
	if output.name == "spawn" or output.name == "spawn_control" then
		label = "Subagent"
		local details = type(output.details) == "table" and output.details or {}
		if type(details.agent) == "string" and details.agent ~= "" then
			label = label .. ": " .. details.agent
		elseif type(details.role) == "string" and details.role ~= "" then
			label = label .. ": " .. details.role
		end
		local status = type(details.status) == "string" and details.status or nil
		local run_id = details.runId or details.id
		local is_spawn_ack = output.name == "spawn"
			and type(run_id) == "string"
			and type(output.text) == "string"
			and output.text:find("Spawned subagent", 1, true) ~= nil
		local progress_source = type(details.progress) == "string" and details.progress or output.text or ""
		local progress = truncate_text(progress_source, is_spawn_ack and 80 or 120)
		if is_spawn_ack then
			status = "spawned"
			progress = short_run_id(run_id) and ("id: " .. short_run_id(run_id)) or ""
		elseif status and progress == status then
			progress = ""
		end
		local parts = { "> 󰇥 " .. label }
		if status and status ~= "" then
			table.insert(parts, status)
		end
		if progress ~= "" then
			table.insert(parts, progress)
		elseif not output.spawn then
			table.insert(parts, line_label)
		end
		if output.spawn then
			table.insert(parts, "artifacts")
		end
		return { table.concat(parts, " · ") }
	elseif is_todo_tool_name(output.name) then
		local status = type(state.todo_status) == "string" and state.todo_status ~= "" and state.todo_status or nil
		return { "> 󰇥 Todo: " .. (status or line_label) }
	elseif output.display and output.display.kind == "bash" and output.display.command then
		label = "Bash: " .. markdown_code_span(command_preview(output.display.command))
		local details = type(output.details) == "table" and output.details or {}
		if details.status == "running" then
			local running_label = lines > 0 and ("running · " .. line_label) or "running"
			return { "> 󰇥 " .. label .. " · " .. running_label }
		end
	elseif output.display and output.display.kind == "file" and output.display.path then
		label = label .. ": " .. markdown_code_span(output.display.path)
	elseif (output.name == "edit" or output.name == "write") and output_path(output) then
		label = label .. ": " .. markdown_code_span(output_path(output))
	end
	local artifact_label = output.spawn and " · artifacts" or ""
	local edit_label = output.name == "edit" and edit_change_label(output.args) or nil
	return {
		"> 󰇥 " .. label .. " · " .. (edit_label or line_label) .. artifact_label,
	}
end

function M.open_float(ctx, output_id)
	local state = ctx.state
	local output = state.tool_outputs[output_id]
	if not output then
		ctx.ui.notify("Tool output unavailable", vim.log.levels.WARN)
		return true
	end
	if output.spawn and open_spawn_artifacts(ctx, output) then
		return true
	end
	if output.name == "edit" and open_edit_diff_float(ctx, output) then
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
	local rendered_text, rendered_filetype = rendered_output(output)
	vim.api.nvim_set_option_value("filetype", rendered_filetype or output.filetype or "text", { buf = buf })
	local content_lines = vim.split(rendered_text or "", "\n", { plain = true })
	local path = output_path(output)
	if path and (output.name == "edit" or output.name == "write") then
		local rendered = { "Path: " .. path, "" }
		vim.list_extend(rendered, content_lines)
		content_lines = rendered
	elseif output.display and output.display.kind == "bash" and output.display.command then
		local command_lines = vim.split(output.display.command, "\n", { plain = true })
		local rendered = {}
		if #command_lines == 1 then
			table.insert(rendered, "$ " .. command_lines[1])
		else
			table.insert(rendered, "$ <<'COMMAND'")
			vim.list_extend(rendered, command_lines)
			table.insert(rendered, "COMMAND")
		end
		table.insert(rendered, "")
		vim.list_extend(rendered, content_lines)
		content_lines = rendered
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, content_lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = path and " Tool: " .. tostring(output.name or "tool") .. " · " .. vim.fn.fnamemodify(path, ":t") .. " " or " Tool: " .. tostring(output.name or "tool") .. " ",
		title_pos = "left",
	})

	vim.api.nvim_set_option_value("wrap", false, { win = win })
	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })

	local close_tool_win = function()
		floats.close_window(win)
	end
	floats.close_on_win_leave(buf, close_tool_win, { win = win, parent = ctx.window.parent })
	vim.keymap.set("n", "q", close_tool_win, { buffer = buf, silent = true, desc = "Close tool output" })
	vim.keymap.set("n", "<Esc>", close_tool_win, { buffer = buf, silent = true, desc = "Close tool output" })
	vim.keymap.set("n", "y", function()
		vim.fn.setreg("+", rendered_text or "")
		ctx.ui.notify("Yanked tool output")
	end, { buffer = buf, silent = true, desc = "Yank tool output" })

	return true
end

return M

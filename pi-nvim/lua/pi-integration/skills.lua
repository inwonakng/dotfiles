local M = {}

local function normalized_path(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	return path:gsub("\\", "/")
end

local function close_window(win)
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

local function sanitize_buf_name_part(value)
	return tostring(value or "skill"):gsub("[^%w%._%-]+", "-")
end

local function read_file(path)
	if type(path) ~= "string" or path == "" or vim.fn.filereadable(path) ~= 1 then
		return nil
	end
	return table.concat(vim.fn.readfile(path), "\n")
end

function M.skill_name_from_read_path(path)
	local normalized = normalized_path(path)
	if not normalized then
		return nil
	end
	if not normalized:find("/skills/", 1, true) then
		return nil
	end

	local parent = normalized:match("^.+/([^/]+)/SKILL%.md$")
	if parent then
		return parent
	end

	local basename = normalized:match("/skills/([^/]+)%.md$")
	if basename then
		return basename
	end

	return nil
end

local function tool_call_id(item)
	return item.id or item.toolCallId or item.tool_call_id or item.callId
end

local function tool_call_arguments(item)
	local args = item.arguments or item.args or item.input
	if type(args) == "table" then
		return args
	end
	return nil
end

local function skill_load_from_content_item(item)
	if type(item) ~= "table" then
		return nil
	end
	if item.type ~= "toolCall" and item.type ~= "tool_call" then
		return nil
	end
	local name = item.name or item.toolName or item.tool_name
	if name ~= "read" then
		return nil
	end
	local args = tool_call_arguments(item)
	local path = args and args.path
	local skill_name = M.skill_name_from_read_path(path)
	if not skill_name then
		return nil
	end
	return {
		name = skill_name,
		path = path,
		tool_call_id = tool_call_id(item),
	}
end

function M.reset(state)
	state.skill_tool_calls = {}
	state.skill_outputs = {}
	state.next_skill_output_id = 0
end

function M.collect_loads(state, message)
	state.skill_tool_calls = state.skill_tool_calls or {}
	local loads = {}
	if type(message) ~= "table" or type(message.content) ~= "table" then
		return loads
	end

	for _, item in ipairs(message.content) do
		local load = skill_load_from_content_item(item)
		if load then
			if load.tool_call_id then
				state.skill_tool_calls[load.tool_call_id] = load
			end
			table.insert(loads, load)
		end
	end
	return loads
end

function M.store_load(state, load)
	if type(load) ~= "table" then
		load = { name = tostring(load or "unknown") }
	end
	state.skill_outputs = state.skill_outputs or {}
	state.next_skill_output_id = (state.next_skill_output_id or 0) + 1
	local id = state.next_skill_output_id
	state.skill_outputs[id] = {
		name = load.name or "unknown",
		path = load.path,
		text = nil,
		filetype = "markdown",
	}
	load.output_id = id
	if load.tool_call_id then
		state.skill_tool_calls = state.skill_tool_calls or {}
		state.skill_tool_calls[load.tool_call_id] = load
	end
	return id
end

local function tool_result_skill_load(state, message)
	if type(message) ~= "table" then
		return nil
	end
	local id = message.toolCallId or message.tool_call_id or message.id
	if not id then
		return nil
	end
	local calls = state.skill_tool_calls or {}
	local load = calls[id]
	if type(load) == "string" then
		return { name = load }
	end
	return load
end

function M.tool_result_skill_name(state, message)
	local load = tool_result_skill_load(state, message)
	return load and load.name or nil
end

function M.apply_tool_result(state, message, text)
	local load = tool_result_skill_load(state, message)
	if not load or not load.output_id then
		return false
	end
	local output = state.skill_outputs and state.skill_outputs[load.output_id]
	if not output then
		return false
	end
	output.text = text or output.text
	return true
end

function M.summary_lines(state, output_id)
	local output = state.skill_outputs and state.skill_outputs[output_id]
	if not output then
		return { "> 󰢱 Skill unavailable." }
	end
	return { "> 󰢱 Using skill: " .. tostring(output.name or "unknown") .. " · press `<CR>` to open" }
end

function M.open_float(ctx, output_id)
	local state = ctx.state
	local output = state.skill_outputs and state.skill_outputs[output_id]
	if not output then
		ctx.notify("Skill prompt unavailable", vim.log.levels.WARN)
		return true
	end

	local text = output.text
	if not text or text == "" then
		text = read_file(output.path)
	end
	if not text or text == "" then
		ctx.notify("Skill prompt unavailable", vim.log.levels.WARN)
		return true
	end

	local width = math.max(40, math.floor(vim.o.columns * 0.85))
	local height = math.max(10, math.floor(vim.o.lines * 0.8))
	width = math.min(width, math.max(1, vim.o.columns - 4))
	height = math.min(height, math.max(1, vim.o.lines - 4))
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "pi://skill/" .. output_id .. "/" .. sanitize_buf_name_part(output.name))
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", output.filetype or "markdown", { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	pcall(vim.treesitter.start, buf, "markdown")

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Skill: " .. tostring(output.name or "unknown") .. " ",
		title_pos = "left",
	})

	vim.api.nvim_set_option_value("wrap", true, { win = win })
	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })

	vim.keymap.set("n", "q", function()
		close_window(win)
	end, { buffer = buf, silent = true, desc = "Close skill prompt" })
	vim.keymap.set("n", "<Esc>", function()
		close_window(win)
	end, { buffer = buf, silent = true, desc = "Close skill prompt" })
	vim.keymap.set("n", "y", function()
		vim.fn.setreg("+", text)
		ctx.notify("Yanked skill prompt")
	end, { buffer = buf, silent = true, desc = "Yank skill prompt" })

	return true
end

return M

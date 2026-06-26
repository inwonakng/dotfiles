local M = {}

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

local function infer_filetype(tool_name, text)
	if looks_like_json(text) then
		return "json"
	end
	if tool_name == "edit" or tool_name == "write" then
		return "diff"
	end
	return "text"
end

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

local function sanitize_buf_name_part(value)
	return tostring(value or "tool"):gsub("[^%w%._%-]+", "-")
end

local function close_window(win)
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

local function read_file_text(path)
	if not path or vim.fn.filereadable(path) ~= 1 then
		return nil
	end
	return table.concat(vim.fn.readfile(path), "\n")
end

local function open_defer_text(ctx, title, path, filetype)
	local state = ctx.state
	local text = read_file_text(path)
	if not text then
		ctx.notify("Could not read " .. tostring(path), vim.log.levels.WARN)
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
		ctx.notify("Yanked defer output")
	end, { buffer = state.defer_buf, silent = true, desc = "Yank defer output" })
end

local function open_defer_artifacts(ctx, output)
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
		ctx.notify("No defer artifacts found for this tool call", vim.log.levels.WARN)
		return true
	end
	vim.ui.select(choices, {
		prompt = "Open defer artifact",
		format_item = function(item)
			return item.label .. "  " .. item.path
		end,
	}, function(choice)
		if choice then
			open_defer_text(ctx, "Defer " .. choice.label, choice.path, choice.filetype)
		end
	end)
	return true
end

function M.reset(state)
	state.tool_outputs = {}
	state.next_tool_output_id = 0
end

function M.store(state, tool_name, text, filetype, details)
	state.next_tool_output_id = state.next_tool_output_id + 1
	local id = state.next_tool_output_id
	state.tool_outputs[id] = {
		name = tool_name or "tool",
		text = text or "",
		filetype = filetype or infer_filetype(tool_name, text),
		details = details,
		defer = defer_artifacts(tool_name, text, details),
	}
	return id
end

function M.summary_lines(state, output_id)
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

function M.open_float(ctx, output_id)
	local state = ctx.state
	local output = state.tool_outputs[output_id]
	if not output then
		ctx.notify("Tool output unavailable", vim.log.levels.WARN)
		return true
	end
	if output.defer and open_defer_artifacts(ctx, output) then
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
		ctx.notify("Yanked tool output")
	end, { buffer = buf, silent = true, desc = "Yank tool output" })

	return true
end

return M

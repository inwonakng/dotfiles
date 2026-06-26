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

local function close_window(win)
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

function M.reset(state)
	state.thinking_outputs = {}
	state.next_thinking_output_id = 0
	state.active_thinking_output_id = nil
	state.active_thinking_line = nil
end

function M.store(state, text)
	state.next_thinking_output_id = state.next_thinking_output_id + 1
	local id = state.next_thinking_output_id
	state.thinking_outputs[id] = {
		text = text or "",
		filetype = "markdown",
	}
	return id
end

function M.append(state, output_id, delta)
	local output = state.thinking_outputs[output_id]
	if not output then
		return
	end
	output.text = (output.text or "") .. (delta or "")
end

function M.text(state, output_id)
	local output = state.thinking_outputs[output_id]
	return output and output.text or nil
end

function M.summary_lines(state, output_id, streaming)
	local output = state.thinking_outputs[output_id]
	if not output then
		return { "> Thinking unavailable." }
	end
	local line_label
	if streaming then
		line_label = "streaming..."
	else
		local lines = line_count_text(output.text)
		line_label = lines == 1 and "1 line" or (tostring(lines) .. " lines")
	end
	return {
		"> 󰔛 Thinking · " .. line_label .. " · press `<CR>` to open",
	}
end

function M.open_float(ctx, output_id)
	local state = ctx.state
	local output = state.thinking_outputs[output_id]
	if not output then
		ctx.notify("Thinking output unavailable", vim.log.levels.WARN)
		return true
	end

	local width = math.max(40, math.floor(vim.o.columns * 0.85))
	local height = math.max(10, math.floor(vim.o.lines * 0.8))
	width = math.min(width, math.max(1, vim.o.columns - 4))
	height = math.min(height, math.max(1, vim.o.lines - 4))
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "pi://thinking/" .. output_id)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", output.filetype or "markdown", { buf = buf })
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
		title = " Thinking ",
		title_pos = "left",
	})

	vim.api.nvim_set_option_value("wrap", true, { win = win })
	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })

	vim.keymap.set("n", "q", function()
		close_window(win)
	end, { buffer = buf, silent = true, desc = "Close thinking output" })
	vim.keymap.set("n", "<Esc>", function()
		close_window(win)
	end, { buffer = buf, silent = true, desc = "Close thinking output" })
	vim.keymap.set("n", "y", function()
		vim.fn.setreg("+", output.text or "")
		ctx.notify("Yanked thinking output")
	end, { buffer = buf, silent = true, desc = "Yank thinking output" })

	return true
end

return M

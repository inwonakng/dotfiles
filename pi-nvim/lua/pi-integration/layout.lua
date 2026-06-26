local M = {}

function M.create_buffer(_, name, filetype, modifiable)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, name)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", filetype, { buf = buf })
	vim.api.nvim_set_option_value("modifiable", modifiable, { buf = buf })
	return buf
end

function M.start_markdown_treesitter(ctx, buf)
	if not ctx.valid_buf(buf) then
		return
	end
	-- pi:// buffers are synthetic nofile buffers, so do not rely on the
	-- normal file read/filetype path to attach Tree-sitter and its injections.
	pcall(vim.treesitter.start, buf, "markdown")
end

function M.set_buffer_lines(ctx, buf, lines, modifiable)
	ctx.set_modifiable(buf, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	ctx.set_modifiable(buf, modifiable)
end

function M.apply_window_padding(_, win)
	vim.api.nvim_set_option_value("winbar", " ", { win = win })
	vim.api.nvim_set_option_value("statusline", "%#PiPaneBorder#%{repeat('─',winwidth(0))}%*", { win = win })
	vim.api.nvim_set_option_value("signcolumn", "yes:1", { win = win })
	vim.api.nvim_set_option_value("scrolloff", 1, { win = win })
	vim.api.nvim_set_option_value("sidescrolloff", 2, { win = win })
end

function M.apply_input_window_options(ctx, win)
	M.apply_window_padding(ctx, win)
	vim.api.nvim_set_option_value("statusline", "%#PiInputTitle# Pi input %#PiPaneBorder#%{repeat('─',max([0,winwidth(0)-10]))}%*", { win = win })
end

function M.apply_transcript_window_options(ctx, win)
	M.apply_window_padding(ctx, win)
	vim.api.nvim_set_option_value("foldenable", true, { win = win })
end

function M.ensure_transcript_buffer(ctx)
	local state = ctx.state
	if ctx.valid_buf(state.transcript_buf) then
		return false
	end

	state.transcript_buf = M.create_buffer(ctx, "pi://transcript", "markdown", false)
	M.start_markdown_treesitter(ctx, state.transcript_buf)
	return true
end

function M.ensure_input_buffer(ctx)
	local state = ctx.state
	if ctx.valid_buf(state.input_buf) then
		return false
	end

	state.input_buf = M.create_buffer(ctx, "pi://input", "markdown", true)
	M.start_markdown_treesitter(ctx, state.input_buf)
	return true
end

function M.show_transcript(ctx)
	local state = ctx.state
	local recreated = M.ensure_transcript_buffer(ctx)
	local win = vim.api.nvim_get_current_win()

	vim.api.nvim_win_set_buf(win, state.transcript_buf)
	state.transcript_win = win
	if state.input_win == win then
		state.input_win = nil
	end
	M.apply_transcript_window_options(ctx, win)
	ctx.setup_keymaps()
	ctx.refresh_transcript_ui()
	return recreated
end

function M.show_input(ctx)
	local state = ctx.state
	local recreated = M.ensure_input_buffer(ctx)
	local win = vim.api.nvim_get_current_win()

	vim.api.nvim_win_set_buf(win, state.input_buf)
	state.input_win = win
	if state.transcript_win == win then
		state.transcript_win = nil
	end
	M.apply_input_window_options(ctx, win)
	ctx.setup_keymaps()
	return recreated
end

function M.open(ctx)
	local state = ctx.state
	if ctx.valid_buf(state.transcript_buf) and ctx.valid_buf(state.input_buf) then
		return false
	end

	M.ensure_transcript_buffer(ctx)
	M.ensure_input_buffer(ctx)

	vim.api.nvim_win_set_buf(0, state.transcript_buf)
	state.transcript_win = vim.api.nvim_get_current_win()
	M.apply_transcript_window_options(ctx, state.transcript_win)
	vim.cmd("botright 12split")
	vim.api.nvim_win_set_buf(0, state.input_buf)
	state.input_win = vim.api.nvim_get_current_win()
	M.apply_input_window_options(ctx, state.input_win)

	ctx.refresh_transcript_ui()
	ctx.append_status(ctx.initial_session_notice)
	ctx.setup_keymaps()
	return true
end

return M

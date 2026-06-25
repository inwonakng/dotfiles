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

function M.apply_transcript_window_options(ctx, win)
	M.apply_window_padding(ctx, win)
	vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
	vim.api.nvim_set_option_value("foldenable", true, { win = win })
	vim.api.nvim_set_option_value("foldlevel", 0, { win = win })
end

function M.open(ctx)
	local state = ctx.state
	if ctx.valid_buf(state.transcript_buf) and ctx.valid_buf(state.input_buf) then
		return false
	end

	state.transcript_buf = M.create_buffer(ctx, "pi://transcript", "markdown", false)
	state.input_buf = M.create_buffer(ctx, "pi://input", "markdown", true)
	M.start_markdown_treesitter(ctx, state.transcript_buf)
	M.start_markdown_treesitter(ctx, state.input_buf)

	vim.api.nvim_win_set_buf(0, state.transcript_buf)
	state.transcript_win = vim.api.nvim_get_current_win()
	M.apply_transcript_window_options(ctx, state.transcript_win)
	vim.cmd("botright 12split")
	vim.api.nvim_win_set_buf(0, state.input_buf)
	state.input_win = vim.api.nvim_get_current_win()
	M.apply_window_padding(ctx, state.input_win)

	ctx.refresh_transcript_ui()
	ctx.append_status(ctx.initial_session_notice)
	ctx.setup_keymaps()
	return true
end

return M

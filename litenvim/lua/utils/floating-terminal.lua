local M = {}

local terminals = {}

function M.toggle_lazygit()
	local term_id = "lazygit"

	-- If terminal exists and is visible, hide it
	if terminals[term_id] and terminals[term_id].win and vim.api.nvim_win_is_valid(terminals[term_id].win) then
		vim.api.nvim_win_hide(terminals[term_id].win)
		terminals[term_id].win = nil
		return
	end

	-- If terminal buffer exists but is hidden, show it
	if terminals[term_id] and terminals[term_id].buf and vim.api.nvim_buf_is_valid(terminals[term_id].buf) then
		M.open_floating_window(terminals[term_id].buf, term_id)
		vim.cmd("startinsert")
		return
	end

	-- Create new terminal
	local buf = vim.api.nvim_create_buf(false, true)
	terminals[term_id] = { buf = buf }

	M.open_floating_window(buf, term_id)
	vim.fn.termopen("lazygit", {
		on_exit = function()
			if terminals[term_id] then
				if terminals[term_id].buf and vim.api.nvim_buf_is_valid(terminals[term_id].buf) then
					vim.api.nvim_buf_delete(terminals[term_id].buf, { force = true })
				end
				terminals[term_id] = nil
			end
		end,
	})
	vim.cmd("startinsert")
end

function M.open_floating_window(buf, term_id)
	local width = math.floor(vim.o.columns * 0.9)
	local height = math.floor(vim.o.lines * 0.9)
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
	})

	terminals[term_id].win = win

	-- Set buffer-local options
	vim.api.nvim_set_option_value("filetype", "floatingterm", { buf = buf })

	-- Auto-hide when leaving the window (optional, can be removed if you don't want this)
	vim.api.nvim_create_autocmd("WinLeave", {
		buffer = buf,
		once = false,
		callback = function()
			-- Only hide if the window is still valid and we're not switching to another float
			if terminals[term_id] and terminals[term_id].win and vim.api.nvim_win_is_valid(terminals[term_id].win) then
				local next_win = vim.api.nvim_get_current_win()
				local next_config = vim.api.nvim_win_get_config(next_win)
				-- If switching to a non-floating window, hide the terminal
				if next_config.relative == "" then
					vim.schedule(function()
						if vim.api.nvim_win_is_valid(terminals[term_id].win) then
							vim.api.nvim_win_hide(terminals[term_id].win)
							terminals[term_id].win = nil
						end
					end)
				end
			end
		end,
	})
end

-- Hide any visible floating terminal
function M.hide_all()
	for _, term in pairs(terminals) do
		if term.win and vim.api.nvim_win_is_valid(term.win) then
			vim.api.nvim_win_hide(term.win)
			term.win = nil
		end
	end
end

-- Check if any terminal is currently visible
function M.is_terminal_visible()
	for _, term in pairs(terminals) do
		if term.win and vim.api.nvim_win_is_valid(term.win) then
			return true
		end
	end
	return false
end

return M

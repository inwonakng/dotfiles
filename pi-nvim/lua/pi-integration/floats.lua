local M = {}

local close_on_leave_augroup = vim.api.nvim_create_augroup("PiTransientFloats", { clear = false })

function M.close_window(win)
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

function M.close_on_win_leave(buf, close_fn)
	if not (buf and vim.api.nvim_buf_is_valid(buf)) then
		return
	end
	vim.api.nvim_create_autocmd("WinLeave", {
		group = close_on_leave_augroup,
		buffer = buf,
		once = true,
		callback = function()
			vim.schedule(function()
				if type(close_fn) == "function" then
					close_fn()
				end
			end)
		end,
	})
end

return M

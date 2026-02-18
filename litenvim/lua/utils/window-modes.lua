local M = {}

local current_mode = "normal"
local is_moving = false
local augroup = vim.api.nvim_create_augroup("WindowModes", { clear = true })

local function clear_mode_keys()
	vim.api.nvim_clear_autocmds({ group = augroup })
	for _, key in ipairs({ "h", "j", "k", "l", "<Esc>", "q" }) do
		pcall(vim.keymap.del, "n", key, { buffer = 0 })
	end
	current_mode = "normal"
end

local function notify_mode(mode)
	local labels = { resize = "RESIZE", normal = "NORMAL" }
	vim.notify("Window mode: " .. labels[mode], vim.log.levels.INFO, { title = "Window" })
end

local function setup_exit_autocmd()
	vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
		group = augroup,
		callback = function()
			if not is_moving then
				clear_mode_keys()
			end
		end,
	})
end

local function enter_mode(mode, keymaps)
	if current_mode == mode then
		clear_mode_keys()
		notify_mode("normal")
		return
	end

	clear_mode_keys()
	current_mode = mode
	notify_mode(mode)

	local opts = { buffer = 0, noremap = true, silent = true }
	local exit = function()
		clear_mode_keys()
		notify_mode("normal")
	end

	for key, action in pairs(keymaps) do
		vim.keymap.set("n", key, action, opts)
	end
	vim.keymap.set("n", "<Esc>", exit, opts)
	vim.keymap.set("n", "q", exit, opts)

	setup_exit_autocmd()
end

function M.enter_resize()
	enter_mode("resize", {
		h = function()
			vim.cmd("vertical resize -2")
		end,
		j = function()
			vim.cmd("resize +2")
		end,
		k = function()
			vim.cmd("resize -2")
		end,
		l = function()
			vim.cmd("vertical resize +2")
		end,
	})
end

function M.get_mode()
	return current_mode
end

return M

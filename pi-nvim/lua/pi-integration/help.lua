local floats = require("pi-integration.floats")
local keymaps = require("pi-integration.keymaps")

local M = {}

function M.toggle(ctx)
	local state = ctx.state
	if state.help_win and vim.api.nvim_win_is_valid(state.help_win) then
		floats.close_window(state.help_win)
		state.help_win = nil
		return
	end

	if not ctx.valid_buf(state.help_buf) then
		state.help_buf = ctx.create_buffer("pi://help", "markdown", false)
	end

	local lines = {
		"# Pi Help",
		"",
		"## Keys",
		"",
	}
	vim.list_extend(lines, keymaps.help_key_lines())
	vim.list_extend(lines, {
		"",
		"## Access Modes",
		"",
		"- `readonly`: allow listed read-only bash commands; ask before other bash, edit, or write tools.",
		"- `write`: allow available tools.",
		"",
		"## Streaming",
		"",
		"When a run is already streaming, submitting another prompt is sent as PI steering for the active run.",
	})
	ctx.set_buffer_lines(state.help_buf, lines, false)

	local width = math.min(72, math.max(48, math.floor(vim.o.columns * 0.55)))
	local height = math.min(#lines + 2, math.max(14, math.floor(vim.o.lines * 0.65)))
	local row = math.max(1, math.floor((vim.o.lines - height) / 2))
	local col = math.max(0, math.floor((vim.o.columns - width) / 2))

	state.help_win = vim.api.nvim_open_win(state.help_buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Pi Help ",
		title_pos = "center",
	})

	local close_help_win = function()
		floats.close_window(state.help_win)
		state.help_win = nil
	end
	floats.close_on_win_leave(state.help_buf, close_help_win)
	vim.keymap.set("n", "q", close_help_win, { buffer = state.help_buf, desc = "Close help" })
	vim.keymap.set("n", "<Esc>", close_help_win, { buffer = state.help_buf, desc = "Close help" })
end

return M

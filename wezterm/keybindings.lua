local io = require("io")
local os = require("os")
local wezterm = require("wezterm")
local utils = require("utils")
local act = wezterm.action

-- if there is a set of defaults that work nicely already, leave them be
local copy_mode = {}
if wezterm.gui then
	copy_mode = wezterm.gui.default_key_tables().copy_mode
end
utils.list_extend(copy_mode, {
	{ key = "v", mods = "LEADER", action = act.CopyMode("Close") },
	{ key = "[", mods = "CTRL", action = act.CopyMode("Close") },
	{
		key = "y",
		action = act.Multiple({
			{ CopyTo = "ClipboardAndPrimarySelection" },
		}),
	},
	-- { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
	{ key = "q", mods = "NONE", action = act.CopyMode("Close") },
})

wezterm.on("trigger-vim-with-scrollback", function(window, pane)
	-- Retrieve the current viewport's text.
	-- Pass an optional number of lines (eg: 2000) to retrieve
	-- that number of lines starting from the bottom of the viewport
	local scrollback = pane:get_logical_lines_as_text(pane:get_dimensions().scrollback_rows)

	-- Create a temporary file to pass to vim
	local name = os.tmpname()
	local f = io.open(name, "w+")
	f:write(scrollback)
	f:flush()
	f:close()
	window:perform_action(
		wezterm.action({
			SpawnCommandInNewWindow = {
				args = { "/opt/homebrew/bin/nvim", "+ normal G $", name },
			},
		}),
		pane
	)
	wezterm.sleep_ms(1000)
	os.remove(name)
end)

return {
	-- leader = { key = "Space", mods = "SHIFT", timeout_milliseconds = 2000 },
	leader = { key = "w", mods = "CTRL"},
	keys = {
		-- turn off keybindings
		{ key = "m", mods = "CMD", action = act.DisableDefaultAssignment },
		{ key = "m", mods = "CTRL", action = act.DisableDefaultAssignment },
		{ key = "Enter", mods = "OPT", action = act.DisableDefaultAssignment },
		-- { key = "w", mods = "CMD", action = act.DisableDefaultAssignment },
		{ key = "-", mods = "CTRL", action = act.DisableDefaultAssignment },
		{ key = "=", mods = "CTRL", action = act.DisableDefaultAssignment },
		{ key = "+", mods = "CTRL", action = act.DisableDefaultAssignment },
		{ key = "h", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
		{ key = "j", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
		{ key = "k", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
		{ key = "l", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
		{ key = "]", mods = "CMD|SHIFT", action = act.DisableDefaultAssignment },
		{ key = "[", mods = "CMD|SHIFT", action = act.DisableDefaultAssignment },
		{ key = "}", mods = "CMD", action = act.DisableDefaultAssignment },
		{ key = "{", mods = "CMD", action = act.DisableDefaultAssignment },
		-- split windows
		{ key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
		{ key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
		-- artifacts from iterm2
		{ key = "Enter", mods = "CMD|SHIFT", action = act.TogglePaneZoomState },
		-- { key = "d", mods = "CMD", action = act.CloseCurrentPane({ confirm = false }) },
		-- { key = "]", mods = "CMD", action = act.ActivatePaneDirection("Next") },
		-- { key = "[", mods = "CMD", action = act.ActivatePaneDirection("Prev") },
		-- vim bindings for pane navigation
		{ key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
		{ key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
		{ key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
		{ key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
		{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
		{ key = "d", mods = "LEADER", action = act.CloseCurrentPane({ confirm = false }) },
		{ key = "v", mods = "LEADER", action = act.ActivateCopyMode },
		-- { key = "f", mods = "LEADER", action = act.ToggleFullScreen },
		-- bring up command palette
		{
			key = ":",
			mods = "LEADER",
			action = wezterm.action.ActivateCommandPalette,
		},
		-- activation pane selection mode
		{
			key = "p",
			mods = "LEADER",
			action = act.PaneSelect,
		},
		-- tab navigator
		{
			key = "r",
			mods = "LEADER",
			action = act.ActivateKeyTable({
				name = "resize_pane",
				one_shot = false,
			}),
		},
		-- Tab keybindings
		{ key = "n", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
		{ key = "[", mods = "LEADER", action = act.ActivateTabRelative(-1) },
		{ key = "]", mods = "LEADER", action = act.ActivateTabRelative(1) },
		{ key = "l", mods = "LEADER|CTRL", action = act.ShowTabNavigator },
		{
			key = "e",
			mods = "LEADER",
			action = act.PromptInputLine({
				description = wezterm.format({
					{ Attribute = { Intensity = "Bold" } },
					{ Foreground = { AnsiColor = "Fuchsia" } },
					{ Text = "Renaming Tab Title...:" },
				}),
				action = wezterm.action_callback(function(window, pane, line)
					if line then
						window:active_tab():set_title(line)
					end
				end),
			}),
		},
		-- use index for tab navigation
		{
			key = "1",
			mods = "LEADER",
			action = act.ActivateTab(0),
		},
		{
			key = "2",
			mods = "LEADER",
			action = act.ActivateTab(1),
		},
		{
			key = "3",
			mods = "LEADER",
			action = act.ActivateTab(2),
		},
		{
			key = "4",
			mods = "LEADER",
			action = act.ActivateTab(3),
		},
		{
			key = "5",
			mods = "LEADER",
			action = act.ActivateTab(4),
		},
		{
			key = "6",
			mods = "LEADER",
			action = act.ActivateTab(5),
		},
		{
			key = "7",
			mods = "LEADER",
			action = act.ActivateTab(6),
		},
		{
			key = "8",
			mods = "LEADER",
			action = act.ActivateTab(7),
		},
		{
			key = "9",
			mods = "LEADER",
			action = act.ActivateTab(8),
		},
		-- Key table for moving tabs around
		{ key = "m", mods = "LEADER", action = act.ActivateKeyTable({ name = "move_tab", one_shot = false }) },
		{
			key = "s",
			mods = "LEADER",
			action = wezterm.action_callback(function(win, pane)
				local tab, window = pane:move_to_new_tab()
			end),
		},
		{
			key = "s",
			mods = "LEADER|SHIFT",
			action = wezterm.action_callback(function(win, pane)
				local tab, window = pane:move_to_new_window()
			end),
		},
		-- commented out for now, seems bugged
		-- { key = "s", mods = "LEADER", action = act.ActivateKeyTable({ name = "rotate_pane", one_shot = false }) },
		-- Or shortcuts to move tab w/o move_tab table. SHIFT is for when caps lock is on
		-- { key = "[", mods = "CMD|CTRL", action = act.MoveTabRelative(-1) },
		-- { key = "]", mods = "CMD|CTRL", action = act.MoveTabRelative(1) },
		{
			key = "v",
			mods = "LEADER",
			action = act.ActivateCopyMode
		},
		{
			key = "V",
			mods = "LEADER",
			action = wezterm.action({ EmitEvent = "trigger-vim-with-scrollback" }),
		},
	},
	key_tables = {
		copy_mode = copy_mode,
		resize_pane = {
			{ key = "h", action = act.AdjustPaneSize({ "Left", 10 }) },
			{ key = "j", action = act.AdjustPaneSize({ "Down", 10 }) },
			{ key = "k", action = act.AdjustPaneSize({ "Up", 10 }) },
			{ key = "l", action = act.AdjustPaneSize({ "Right", 10 }) },
			{ key = "Escape", action = "PopKeyTable" },
			{ key = "Enter", action = "PopKeyTable" },
			{ key = "q", action = "PopKeyTable" },
			{ key = "[", mods = "CTRL", action = "PopKeyTable" },
		},
		move_tab = {
			{ key = "h", action = act.MoveTabRelative(-1) },
			{ key = "j", action = act.MoveTabRelative(-1) },
			{ key = "k", action = act.MoveTabRelative(1) },
			{ key = "l", action = act.MoveTabRelative(1) },
			{ key = "Escape", action = "PopKeyTable" },
			{ key = "Enter", action = "PopKeyTable" },
			{ key = "q", action = "PopKeyTable" },
			{ key = "[", mods = "CTRL", action = "PopKeyTable" },
		},
		-- rotate_pane = {
		-- 	{ key = "h", action = act.RotatePanes("CounterClockwise") },
		-- 	{ key = "j", action = act.RotatePanes("Clockwise") },
		-- 	{ key = "k", action = act.RotatePanes("CounterClockwise") },
		-- 	{ key = "l", action = act.RotatePanes("Clockwise") },
		-- 	{ key = "Escape", action = "PopKeyTable" },
		-- 	{ key = "Enter", action = "PopKeyTable" },
		-- 	{ key = "q", action = "PopKeyTable" },
		-- 	{ key = "[", mods = "CTRL", action = "PopKeyTable" },
		-- },
	},
}

local wezterm = require("wezterm")
local utils = require("utils")
local act = wezterm.action

-- if there is a set of defaults that work nicely already, leave them be
local copy_mode = {}
if wezterm.gui then
	copy_mode = wezterm.gui.default_key_tables().copy_mode
end
utils.list_extend(copy_mode, {
	-- { key = "[", mods = "CTRL", action = act.CopyMode("Close") },
	-- { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
	{ key = "v", mods = "LEADER", action = act.CopyMode("Close") },
})

return {
	-- leader = { key = "Space", mods = "SHIFT", timeout_milliseconds = 2000 },
	leader = { key = "w", mods = "CTRL", timeout_milliseconds = 2000 },
	keys = {
		-- turn off keybindings
		{ key = "m", mods = "CMD", action = act.DisableDefaultAssignment },
		{ key = "m", mods = "CTRL", action = act.DisableDefaultAssignment },
		-- { key = "w", mods = "CMD", action = act.DisableDefaultAssignment },
		{ key = "-", mods = "CTRL", action = act.DisableDefaultAssignment },
		{ key = "=", mods = "CTRL", action = act.DisableDefaultAssignment },
		{ key = "+", mods = "CTRL", action = act.DisableDefaultAssignment },
		-- split windows
		{ key = "|", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
		{ key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
		-- artifacts from iterm2
		{ key = "Enter", mods = "CMD|SHIFT", action = act.TogglePaneZoomState },
		-- { key = "d", mods = "CMD", action = act.CloseCurrentPane({ confirm = false }) },
		{ key = "]", mods = "CMD", action = act.ActivatePaneDirection("Next") },
		{ key = "[", mods = "CMD", action = act.ActivatePaneDirection("Prev") },
		-- vim bindings for pane navigation
		{ key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
		{ key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
		{ key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
		{ key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
		{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
		{ key = "d", mods = "LEADER", action = act.CloseCurrentPane({ confirm = false }) },
		{ key = "v", mods = "LEADER", action = act.ActivateCopyMode },
		{
			key = "r",
			mods = "LEADER",
			action = act.ActivateKeyTable({
				name = "resize_pane",
				one_shot = false,
			}),
		},

		-- Tab keybindings
		{ key = "t", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
		{ key = "[", mods = "LEADER", action = act.ActivateTabRelative(-1) },
		{ key = "]", mods = "LEADER", action = act.ActivateTabRelative(1) },
		{ key = "n", mods = "LEADER", action = act.ShowTabNavigator },
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
		-- Key table for moving tabs around
		{ key = "m", mods = "LEADER", action = act.ActivateKeyTable({ name = "move_tab", one_shot = false }) },
		-- Or shortcuts to move tab w/o move_tab table. SHIFT is for when caps lock is on
		{ key = "[", mods = "SHIFT|CTRL", action = act.MoveTabRelative(-1) },
		{ key = "]", mods = "SHIFT|CTRL", action = act.MoveTabRelative(1) },
	},
	key_tables = {
		copy_mode = copy_mode,
		resize_pane = {
			{ key = "h", action = act.AdjustPaneSize({ "Left", 1 }) },
			{ key = "j", action = act.AdjustPaneSize({ "Down", 1 }) },
			{ key = "k", action = act.AdjustPaneSize({ "Up", 1 }) },
			{ key = "l", action = act.AdjustPaneSize({ "Right", 1 }) },
			{ key = "Escape", action = "PopKeyTable" },
			{ key = "Enter", action = "PopKeyTable" },
		},
		move_tab = {
			{ key = "h", action = act.MoveTabRelative(-1) },
			{ key = "j", action = act.MoveTabRelative(-1) },
			{ key = "k", action = act.MoveTabRelative(1) },
			{ key = "l", action = act.MoveTabRelative(1) },
			{ key = "Escape", action = "PopKeyTable" },
			{ key = "Enter", action = "PopKeyTable" },
		},
	},
}

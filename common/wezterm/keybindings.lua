local wezterm = require("wezterm")
local utils = require("utils")
local act = wezterm.action

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
	leader = { key = "Space", mods = "SHIFT", timeout_milliseconds = 2000 },
	keys = {
		-- turn off keybindings
		{ key = "m", mods = "CMD", action = act.DisableDefaultAssignment },
		{ key = "w", mods = "CMD", action = act.DisableDefaultAssignment },
		{ key = "-", mods = "CTRL", action = act.DisableDefaultAssignment },
		{ key = "=", mods = "CTRL", action = act.DisableDefaultAssignment },
		{ key = "+", mods = "CTRL", action = act.DisableDefaultAssignment },
		-- split windows
		{ key = "|", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
		{ key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
		-- artifacts from iterm2
		{ key = "Enter", mods = "CMD|SHIFT", action = act.TogglePaneZoomState },
		{ key = "w", mods = "CMD", action = act.CloseCurrentPane({ confirm = false }) },
		{ key = "]", mods = "CMD", action = act.ActivatePaneDirection("Next") },
		{ key = "[", mods = "CMD", action = act.ActivatePaneDirection("Prev") },
		-- vim bindings for pane navigation
		{ key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
		{ key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
		{ key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
		{ key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
		{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
		{ key = "q", mods = "LEADER", action = act.CloseCurrentPane({ confirm = false }) },
		{ key = "v", mods = "LEADER", action = act.ActivateCopyMode },
	},
	key_tables = {
		copy_mode = copy_mode,
	},
}

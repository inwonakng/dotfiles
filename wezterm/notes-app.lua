-- Same thing as the wezterm.lua but for a specific application.
local wezterm = require("wezterm")
local config = require("default-config")

-- custom logic here
wezterm.on("format-window-title", function()
	return "notes"
end)

local work_notes = "/Users/inwon/Library/Mobile Documents/iCloud~md~obsidian/Documents/work"
local personal_notes = "/Users/inwon/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal"

wezterm.on("gui-startup", function(cmd)
	local tab1, pane1, window = wezterm.mux.spawn_window({
		cwd = work_notes,
	})
	pane1:send_text("nvim -c 'lua require(\"persistence\").load()'\n")
	tab1:set_title("notes/work")
	local tab2, pane2 = window:spawn_tab({
		cwd = personal_notes,
	})
	pane2:send_text("nvim -c 'lua require(\"persistence\").load()'\n")
	tab2:set_title("notes/personal")
	pane1:activate()
end)

return config

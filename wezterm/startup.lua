local wezterm = require("wezterm")
local mux = wezterm.mux

-- local notes_dir = "/Users/inwon/Library/Mobile Documents/iCloud~md~obsidian/Documents/"
local notes_dir = os.getenv("HOME") .. "/Documents/notes/"
local work_dir = os.getenv("HOME") .. "/research/"

wezterm.on("gui-startup", function(cmd)
	local mode = os.getenv("WEZTERM_STARTUP_MODE")
	if mode == "notes" then
		local tab1, pane1, window = mux.spawn_window({
			-- workspace = "main",
			cwd = notes_dir .. "work",
		})
		tab1:set_title("work")
		pane1:send_text("load nvm\nnvim -c \"lua require('persistence').load()\"\n")
		local tab2, pane2, _ = window:spawn_tab({
			-- workspace = "main",
			cwd = notes_dir .. "personal",
		})
		tab2:set_title("personal")
		pane2:send_text("load nvm\nnvim -c \"lua require('persistence').load()\"\n")
	elseif mode == "editor" then
		local tab, pane, window = mux.spawn_window({
			-- workspace = "main",
			cwd = work_dir,
		})
		tab:set_title("code")
		pane:send_text("load nvm && load conda\n")
	elseif mode == "interactive" then
		local tab, pane, window = mux.spawn_window({
			-- workspace = "main",
			cwd = work_dir,
		})
		tab:set_title("interactive")
		pane:send_text("load nvm && load conda\n")
	end
end)

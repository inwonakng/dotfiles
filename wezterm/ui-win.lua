local wezterm = require("wezterm")

local status_settings = {
	normal = {
		icon = wezterm.nerdfonts.cod_terminal,
		color = "#f7768e",
		text = "NORMAL",
	},
	leader = {
		icon = wezterm.nerdfonts.cod_terminal,
		color = "#bb9af7",
		text = "LEADER",
	},
	copy_mode = {
		icon = wezterm.nerdfonts.oct_copy,
		color = "#57abfa",
		text = "COPY",
	},
	resize_pane = {
		icon = wezterm.nerdfonts.oct_arrow_up_right,
		color = "#5bc25f",
		text = "RESIZE PANE",
	},
	move_tab = {
		icon = wezterm.nerdfonts.oct_tab,
		color = "#dee851",
		text = "MOVE TAB",
	},
}

local tab_bar_background = "#231d30"

wezterm.on("update-status", function(window, pane)
	local status = "normal"
	local stat_color = "#f7768e"

	if window:active_key_table() then
		status = window:active_key_table()
		-- print("keytable is active!")
		-- print(status)
	end
	if window:leader_is_active() then
		status = "leader"
	end

	local parse_cwd = function(s)
		return s.path:gsub("%/Users/inwon", "~")
	end

	local parse_cmd = function(s)
		return s:match("([^/]+)$")
	end

	-- CWD and CMD could be nil (e.g. viewing log using Ctrl-Alt-l). Not a big deal, but check in case
	local cwd = pane:get_current_working_dir()
	cwd = cwd and parse_cwd(cwd) or ""
	local cmd = pane:get_foreground_process_name()
	cmd = cmd and parse_cmd(cmd) or ""

	window:set_left_status(wezterm.format({
		-- { Background = {Color = tab_bar_background } },
		{ Foreground = { Color = status_settings[status].color } },
		{ Text = "  " },
		{ Text = status_settings[status].icon .. "  " .. status_settings[status].text },
		{ Text = " " },
	}))

	window:set_right_status(wezterm.format({
		-- { Background = {Color = tab_bar_background } },
		{ Text = wezterm.nerdfonts.md_folder .. "  " .. cwd },
		{ Text = "  " },
		{ Foreground = { Color = "#e0af68" } },
		{ Text = wezterm.nerdfonts.fa_code .. "  " .. cmd },
		{ Text = "  " },
		{ Foreground = { Color = "#58d6a7" } },
		{ Text = "#" .. pane:pane_id() .. " " },
		-- "ResetAttributes",
	}))
end)

-- This function returns the suggested title for a tab.
-- It prefers the title that was set via `tab:set_title()`
-- or `wezterm cli set-tab-title`, but falls back to the
-- title of the active pane in that tab.
local function tab_title(tab_info)
	local title = tab_info.active_pane.title
	-- if the tab title is explicitly set, take that
	if tab_info.tab_title and #tab_info.tab_title > 0 then
		title = tab_info.tab_title
	end
	return tab_info.tab_index + 1 .. ". " .. title
end

-- Hook for formatting tab title
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	local background = "#443c52"
	local foreground = "#a6a6a6"

	if tab.is_active then
		background = "#645480"
		foreground = "#d9d9d9"
	elseif hover then
		background = "#8062b3"
		foreground = "#c2c2c2"
	end

	local edge_foreground = background
	local title = tab_title(tab)

	-- ensure that the titles fit in the available space,
	-- and that we have room for the edges.
	title = wezterm.truncate_right(title, max_width - 2)

	return {
		{ Background = { Color = tab_bar_background } },
		{ Foreground = { Color = edge_foreground } },
		{ Text = " " },
		{ Text = wezterm.nerdfonts.ple_left_half_circle_thick },
		{ Background = { Color = background } },
		{ Foreground = { Color = foreground } },
		{ Attribute = { Intensity = "Bold" } },
		{ Text = title },
		{ Background = { Color = tab_bar_background } },
		{ Foreground = { Color = edge_foreground } },
		{ Text = wezterm.nerdfonts.ple_right_half_circle_thick },
		{ Text = "" },
	}
end)

return {
	color_scheme = "catppuccin-frappe",
	font = wezterm.font_with_fallback({
		{ family = "IBM Plex Mono" },
		-- { family = "UbuntuMono Nerd Font" },
		-- { family = "Nerd Font" },
	}),
	font_size = 11,
	hide_tab_bar_if_only_one_tab = false,
	window_padding = {
		left = 2,
		right = 2,
		top = 0,
		bottom = 0,
	},
	window_decorations = "TITLE | RESIZE",
	status_update_interval = 1000,
	inactive_pane_hsb = {
		saturation = 0.5,
		brightness = 0.5,
	},
	use_fancy_tab_bar = false,
	tab_bar_at_bottom = true,
	colors = {
		tab_bar = {
			-- background = "#0b0022",
			-- background = "rgb(11, 0, 34)",
			background = tab_bar_background,
		},
		cursor_bg = "rgb(193, 169, 217)",
		cursor_fg = "rgb(79, 29, 171)",
		-- cursor_fg = "black",
	},
	show_new_tab_button_in_tab_bar = false,
	show_tab_index_in_tab_bar = true,
	tab_max_width = 24,
}

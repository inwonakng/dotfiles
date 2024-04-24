local wezterm = require("wezterm")

wezterm.on("update-status", function(window, pane)
	local stat = window:active_workspace()
	local stat_color = "#f7768e"
	-- It's a little silly to have workspace name all the time
	-- Utilize this to display LDR or current key table name
	if window:active_key_table() then
		stat = window:active_key_table()
		stat_color = "#7dcfff"
	end
	if window:leader_is_active() then
		stat = "LDR"
		stat_color = "#bb9af7"
	end

	-- Current working directory
	local basename = function(s)
		-- Nothing a little regex can't fix
		return string.gsub(s, "(.*[/\\])(.*)", "%2")
	end
	-- CWD and CMD could be nil (e.g. viewing log using Ctrl-Alt-l). Not a big deal, but check in case
	local cwd = pane:get_current_working_dir()
	cwd = cwd and basename(cwd) or ""
	-- Current command
	local cmd = pane:get_foreground_process_name()
	cmd = cmd and basename(cmd) or ""

	-- Time
	local time = wezterm.strftime("%H:%M")

	window:set_left_status(wezterm.format({
		{ Foreground = { Color = stat_color } },
		{ Text = "  " },
		{ Text = wezterm.nerdfonts.oct_table .. "  " .. stat },
		{ Text = " |" },
	}))

	window:set_right_status(wezterm.format({
		{ Text = wezterm.nerdfonts.md_folder .. "  " .. cwd },
		{ Text = " | " },
		{ Foreground = { Color = "#e0af68" } },
		{ Text = wezterm.nerdfonts.fa_code .. "  " .. cmd },
		"ResetAttributes",
		{ Text = " | " },
		{ Text = wezterm.nerdfonts.md_clock .. "  " .. time },
		{ Text = "  " },
	}))
end)

-- This function returns the suggested title for a tab.
-- It prefers the title that was set via `tab:set_title()`
-- or `wezterm cli set-tab-title`, but falls back to the
-- title of the active pane in that tab.
function tab_title(tab_info)
  local title = tab_info.tab_title
  -- if the tab title is explicitly set, take that
  if title and #title > 0 then
    return title
  end
  -- Otherwise, use the title from the active pane
  -- in that tab
  return tab_info.active_pane.title
end

-- Hook for formatting tab title
wezterm.on(
  'format-tab-title',
  function(tab, tabs, panes, config, hover, max_width)
    local edge_background = '#0b0022'
    local background = '#1b1032'
    local foreground = '#808080'

    if tab.is_active then
      background = '#2b2042'
      foreground = '#c0c0c0'
    elseif hover then
      background = '#3b3052'
      foreground = '#909090'
    end

    local edge_foreground = background
    local title = tab_title(tab)

    -- ensure that the titles fit in the available space,
    -- and that we have room for the edges.
    title = wezterm.truncate_right(title, max_width - 2)

    return {
      { Background = { Color = edge_background } },
      { Foreground = { Color = edge_foreground } },
      { Text = " " },
      { Text = wezterm.nerdfonts.ple_left_half_circle_thick },
      { Background = { Color = background } },
      { Foreground = { Color = foreground } },
      { Attribute = { Intensity = "Bold" } },
      -- { Text = tab.index },
      { Text = title },
      { Background = { Color = edge_background } },
      { Foreground = { Color = edge_foreground } },
      { Text = wezterm.nerdfonts.ple_right_half_circle_thick },
      { Text = " " },
    }
  end
)

return {
	color_scheme = "catppuccin-frappe",
	font = wezterm.font_with_fallback({
		{ family = "UbuntuMono Nerd Font" },
		{ family = "Nerd Font" },
	}),
	font_size = 17,
	hide_tab_bar_if_only_one_tab = true,
	window_padding = {
		left = 2,
		right = 2,
		top = 0,
		bottom = 0,
	},
	window_decorations = "RESIZE",
	status_update_interval = 1000,
	inactive_pane_hsb = {
		saturation = 0.5,
		brightness = 0.5,
	},
	use_fancy_tab_bar = false,
	tab_bar_at_bottom = true,
	colors = {
		tab_bar = {
			background = "#0b0022",
		},
	},
  show_new_tab_button_in_tab_bar = false,
  show_tab_index_in_tab_bar = true,
}

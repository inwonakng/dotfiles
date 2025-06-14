-- ~/.config/wezterm/my_special_app.lua
local wezterm = require("wezterm")
local config = {}

-- It's often good practice to inherit from the default config
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- Custom settings for this "app"
config.window_background_opacity = 0.85
config.color_scheme = "Catppuccin Mocha"
config.initial_cols = 100
config.initial_rows = 30
config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}
config.font = wezterm.font("JetBrains Mono")

-- You can even set a default title for new tabs in this instance
config.window_decorations = "RESIZE" -- Minimal decorations
config.default_prog = { "/bin/bash", "-l", "-c", 'echo "Welcome to My Special App!"; zsh' } -- Example command
-- Or perhaps launch a specific tool like 'lazygit' or 'btop'
-- config.default_prog = {'lazygit'}

-- Important for window manager identification if it uses window titles
wezterm.on("format-window-title", function(tab, pane, tabs, panes, config)
	return "MySpecialApp - " .. tab.active_pane.title
end)

return config

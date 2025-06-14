local wezterm = require("wezterm")
local config = require("default-config")

wezterm.on("format-window-title", function()
	return "default"
end)

return config

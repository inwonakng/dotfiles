local wezterm = require("wezterm")
local utils = require("utils")
local ui = require("ui")
local env = require("env")
local keybindings = require("keybindings")

-- wezterm.log_error('Exe dir ' .. wezterm.version)

local config = {}
if wezterm.config_builder then
	config = wezterm.config_builder()
end

utils.update_config(config, ui)
utils.update_config(config, keybindings)
utils.update_config(config, env)

return config

local wezterm = require("wezterm")
local utils = require("utils")
local env = require("env")
local domains = require("domains")
local keymaps = require("keymaps")
local options = require("options")
if utils.get_os() == "Windows" then
  local ui = require("ui-windows")
else
  local ui = require("ui")
end
require("startup")

local config = {}
if wezterm.config_builder then
	config = wezterm.config_builder()
end

utils.update_config(config, ui)
utils.update_config(config, keymaps)
utils.update_config(config, env)
utils.update_config(config, domains)
utils.update_config(config, options)

return config

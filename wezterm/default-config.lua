local wezterm = require("wezterm")
local utils = require("utils")
local ui = require("ui")
local env = require("env")
local domains = require("domains")
local keymaps = require("keymaps")
local options = require("options")
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

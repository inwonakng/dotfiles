local M = {}
local wezterm = require("wezterm")

function M.update_config(config, options)
	for k, v in pairs(options) do
		config[k] = v
	end
end

function M.list_extend(list, options)
	for _, o in ipairs(options) do
		table.insert(list, o)
	end
end

return M

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

function M.get_os()
  if jit then
    return jit.os
  end

  local fh, err = assert(io.popen("uname -o 2>/dev/null", "r"))
  if fh then
    osname = fh:read()
  end
  return osname or "Windows"
end

return M


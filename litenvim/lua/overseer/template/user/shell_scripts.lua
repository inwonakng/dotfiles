local files = require("overseer.files")

return {
  generator = function(opts, callback)
    local cwd = vim.fn.getcwd()
    local script_dir = cwd .. "/scripts"
    -- if script dir is not intialized, skip
    if vim.fn.isdirectory(script_dir) == 0 then
      return callback({})
    else
      local scripts = vim.tbl_filter(function(filename)
        return filename:match("%.sh$")
      end, files.list_files(script_dir))
      local ret = {}
      for _, filename in ipairs(scripts) do
        table.insert(ret, {
          name = filename:gsub("%_", " "):gsub("%-", " "):gsub("%.sh", ""),
          params = {
            args = { optional = true, type = "list", delimiter = " " },
          },
          builder = function(params)
            return {
              cmd = { "bash", "scripts/" .. filename },
              args = params.args,
            }
          end,
        })
      end
      return callback(ret)
    end
  end,
}

local files = require("overseer.files")

return {
  generator = function(opts, callback)
    local cwd = vim.fn.getcwd()
    local scripts = vim.tbl_filter(function(filename)
      return filename:match("%.sh$")
    end, files.list_files(cwd .. "/scripts"))
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
    callback(ret)
  end,
}

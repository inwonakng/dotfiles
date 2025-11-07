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
			-- ignore scripts that start with underscore
			for _, filename in ipairs(scripts) do
				if not filename:match("^_.*") then
					table.insert(ret, {
						name = filename:gsub("%_", " "):gsub("%-", " "):gsub("%.sh", ""):match("^%s*(.-)%s*$"),
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
			end
			return callback(ret)
		end
	end,
}

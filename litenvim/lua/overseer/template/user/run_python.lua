return {
	name = "Run python script",
	builder = function(params)
		local file = vim.fn.expand("%:.") -- Get current file's path relative to cwd
		local cwd = vim.fn.getcwd()
		-- Convert path to module: exp/analysis/myscript.py -> exp.analysis.myscript
		local module = file:gsub("%.py$", ""):gsub("/", ".")
		local cmd = { "pixi", "run", "python", "-m", module }
		vim.notify(
			string.format("Running: %s\nCWD: %s", table.concat(cmd, " "), cwd),
			vim.log.levels.INFO
		)
		return {
			cmd = cmd,
			name = "python " .. vim.fn.expand("%:t"),
			cwd = cwd,
		}
	end,
	desc = "Run this file as a python script using pixi.",
	condition = {
		filetype = { "python" },
	},
}

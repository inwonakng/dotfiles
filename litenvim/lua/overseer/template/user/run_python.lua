return {
	name = "Run python script",
	builder = function(params)
		local file = vim.fn.expand("%:p") -- Get current file's full path
		return {
			cmd = { "pixi", "run", "python", file },
			name = "python " .. vim.fn.expand("%:t"), -- Shows filename in task list
		}
	end,
	desc = "Run this file as a python script using pixi.",
	condition = {
		filetype = { "python" },
	},
}

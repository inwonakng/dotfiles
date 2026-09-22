-- Only persist sessions started without file arguments unless explicitly disabled.
if vim.fn.argc() > 0 or vim.env.NVIM_NO_PERSISTENCE == "1" then
	return
end

vim.pack.add({ "https://github.com/folke/persistence.nvim" })
local persistence = require("persistence")
persistence.setup()

local function close_unnamed_buffers()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == "" then
			vim.cmd("bd " .. buf)
		end
	end
end

vim.api.nvim_create_autocmd("VimEnter", {
	nested = true,
	callback = function()
		if vim.g.started_with_stdin then
			return
		end

		persistence.load()
		close_unnamed_buffers()
		vim.schedule(function()
			vim.cmd("doautoall BufRead")
		end)
	end,
})

vim.fn.timer_start(5 * 60 * 1000, function()
	if persistence.active() then
		persistence.save()
	end
end, { ["repeat"] = -1 })

vim.keymap.set("n", "<leader>qs", function()
	persistence.load()
end)

local M = {}

local ns = vim.api.nvim_create_namespace("numi_results")
local results = {} -- row (0-indexed) -> result string

function M.eval_line(bufnr)
	local line = vim.api.nvim_get_current_line()
	if line:match("^%s*$") then
		return
	end

	local result = vim.fn.system("numi-cli " .. vim.fn.shellescape(line))
	result = result:gsub("%s+$", "")

	local row = vim.api.nvim_win_get_cursor(0)[1] - 1

	-- Clear any existing result on this line
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, { row, 0 }, { row, -1 }, {})
	for _, mark in ipairs(marks) do
		vim.api.nvim_buf_del_extmark(bufnr, ns, mark[1])
	end

	results[row] = result
	vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
		virt_lines = { { { " = " .. result, "Comment" } } },
		virt_lines_above = false,
	})
end

function M.setup(bufnr)
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].swapfile = false

	vim.keymap.set("n", "<CR>", function()
		M.eval_line(bufnr)
	end, { buffer = bufnr, desc = "Evaluate line with numi" })
	vim.keymap.set("n", "R", function()
		vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
		results = {}
	end, { buffer = bufnr, desc = "Clear all numi results" })
  -- unmapp yank path commands since we don't really need it and they interfere
	vim.keymap.set("n", "<leader>yp", "<Nop>", { buffer = bufnr })
	vim.keymap.set("n", "<leader>yP", "<Nop>", { buffer = bufnr })
	vim.keymap.set("n", "<leader>y", function()
		local row = vim.api.nvim_win_get_cursor(0)[1] - 1
		local result = results[row]
		if not result then
			return
		end
		vim.fn.setreg("+", result:gsub("\n", ""))
		vim.notify("Yanked: " .. result)
	end, { buffer = bufnr, desc = "Yank numi result for current line" })
end

return M

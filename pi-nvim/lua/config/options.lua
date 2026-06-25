vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.laststatus = 2
vim.opt.showmode = false
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.termguicolors = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.hidden = true

vim.schedule(function()
	vim.opt.clipboard = "unnamedplus"
end)

vim.api.nvim_create_autocmd({ "BufWinEnter", "VimResized", "WinResized" }, {
	callback = function()
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.api.nvim_buf_get_name(buf):match("pi://input$") then
				vim.api.nvim_set_option_value("wrap", true, { win = win })
				vim.api.nvim_set_option_value("linebreak", true, { win = win })
				vim.api.nvim_set_option_value("breakindent", true, { win = win })
			end
		end
	end,
})

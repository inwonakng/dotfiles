local map = vim.keymap.set
local del = vim.keymap.del

map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit" })
map("n", "<leader>wd", "<cmd>q<cr>", { desc = "Close Window" })
map("n", "<leader>\\", "<cmd>vsplit<cr>", { desc = "Vertical split" })
map("n", "<leader>-", "<cmd>split<cr>", { desc = "Horizontal split" })

map("n", "<leader><tab>]", "<cmd>tabnext<cr>", { desc = "Next tab" })
map("n", "<leader><tab>[", "<cmd>tabprev<cr>", { desc = "Previous tab" })
map("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", { desc = "New tab" })

-- disabled bufferline, using bo to close all other buffers
map("n", "<leader>bo", function()
	local bufs = vim.api.nvim_list_bufs()
	-- local current_buf = vim.api.nvim_get_current_buf()
	local non_hidden_buffer = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		non_hidden_buffer[vim.api.nvim_win_get_buf(win)] = true
	end
	for _, i in ipairs(bufs) do
		if non_hidden_buffer[i] == nil then
			vim.api.nvim_buf_delete(i, {})
		end
	end
end, { desc = "delete hidden buffers" })

map("n", "yP", ":YankFilePath<CR>", { noremap = true, silent = true })
map("n", "yp", ":YankRelativeFilePath<CR>", { noremap = true, silent = true })
map("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
map("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
map("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
map("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

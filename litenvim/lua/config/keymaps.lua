-- window manipulation
vim.keymap.set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit" })
vim.keymap.set("n", "<leader>wd", "<cmd>q<cr>", { desc = "Close Window" })
vim.keymap.set("n", "<leader>\\", "<cmd>vsplit<cr>", { desc = "Vertical split" })
vim.keymap.set("n", "<leader>-", "<cmd>split<cr>", { desc = "Horizontal split" })
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- tab manipulation
vim.keymap.set("n", "<leader><tab>]", "<cmd>tabnext<cr>", { desc = "Next tab" })
vim.keymap.set("n", "<leader><tab>[", "<cmd>tabprev<cr>", { desc = "Previous tab" })
vim.keymap.set("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", { desc = "New tab" })
vim.keymap.set("n", "<leader><tab><cr>", "<cmd>tab sp<cr>", { desc = "Open in new tab" })
vim.keymap.set("n", "<leader><tab>o", "<cmd>tabonly<cr>", { desc = "Close other tabs" })
vim.keymap.set("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close tab" })

-- indentation with >> and <<
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

-- nice trick to kill all hidden buffers.
vim.keymap.set("n", "<leader>bo", function()
	local bufs = vim.api.nvim_list_bufs()
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

-- some nice UI controls.
vim.keymap.set("n", "<leader>uw", "<cmd>set wrap!<CR>", { desc = "Toggle wrap" })
vim.keymap.set("n", "<leader>us", "<cmd>set spell!<CR>", { desc = "Toggle spell check" })
vim.keymap.set("n", "<leader>un", "<cmd>set relativenumber!<CR>", { desc = "Toggle number" })

-- let j and k move up and down lines that have been wrapped
vim.keymap.set({ "n", "v" }, "j", function()
	return vim.v.count == 0 and "gj" or "j"
end, { expr = true, noremap = true })

vim.keymap.set({ "n", "v" }, "k", function()
	return vim.v.count == 0 and "gk" or "k"
end, { expr = true, noremap = true })

-- format code. Since we have all the formatters from mason, I don't think we need conform.
-- vim.keymap.set({ "n", "v" }, "<leader>cf",
--   function()
--     vim.lsp.buf.format()
--   end,
--   { desc = "Format Buffer" }
-- )

-- Yank file path
vim.keymap.set("n", "yP", ":YankFilePath<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "yp", ":YankRelativeFilePath<CR>", { noremap = true, silent = true })

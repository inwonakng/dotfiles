local map = vim.keymap.set

-- window manipulation
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit" })
map("n", "<leader>wd", "<cmd>q<cr>", { desc = "Close Window" })
map("n", "<leader>\\", "<cmd>vsplit<cr>", { desc = "Vertical split" })
map("n", "<leader>-", "<cmd>split<cr>", { desc = "Horizontal split" })
map("n", "<leader>w", "<C-w>", { desc = "Window commands" })
map("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
map("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
map("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
map("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- tab manipulation
map("n", "<leader><tab>]", "<cmd>tabnext<cr>", { desc = "Next tab" })
map("n", "<leader><tab>[", "<cmd>tabprev<cr>", { desc = "Previous tab" })
map("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", { desc = "New tab" })
map("n", "<leader><tab><cr>", "<cmd>tab sp<cr>", { desc = "Open in new tab" })
map("n", "<leader><tab>o", "<cmd>tabonly<cr>", { desc = "Close other tabs" })
map("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close tab" })

-- indentation with >> and <<
map("v", "<", "<gv")
map("v", ">", ">gv")

-- nice trick to kill all hidden buffers.
map("n", "<leader>bo", function()
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
map("n", "<leader>uw", "<cmd>set wrap!<CR>", { desc = "Toggle wrap" })
map("n", "<leader>us", "<cmd>set spell!<CR>", { desc = "Toggle spell check" })
map("n", "<leader>un", "<cmd>set relativenumber!<CR>", { desc = "Toggle number" })

-- let j and k move up and down lines that have been wrapped
map({ "n", "v" }, "j", function()
	return vim.v.count == 0 and "gj" or "j"
end, { expr = true, noremap = true })

map({ "n", "v" }, "k", function()
	return vim.v.count == 0 and "gk" or "k"
end, { expr = true, noremap = true })

-- Yank file path
map("n", "yP", ":YankFilePath<CR>", { noremap = true, silent = true })
map("n", "yp", ":YankRelativeFilePath<CR>", { noremap = true, silent = true })

map("n", "<leader>cd", function()
	vim.diagnostic.open_float()
end, { desc = "Show Diagnostic", noremap = true, silent = true })

-- Toggle harper-ls spell checking
map("n", "<leader>cp", function()
	local bufnr = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "harper_ls" })

	if #clients > 0 then
		-- Harper is running, stop it
		for _, client in ipairs(clients) do
			vim.lsp.stop_client(client.id)
		end
		vim.notify("Harper-LS disabled", vim.log.levels.INFO)
	else
		-- Harper is not running, start it
		vim.lsp.start({
			name = "harper_ls",
			cmd = { "harper-ls", "--stdio" },
			root_dir = vim.fs.root(bufnr, { ".git" }) or vim.fn.getcwd(),
		})
		vim.notify("Harper-LS enabled", vim.log.levels.INFO)
	end
end, { desc = "Toggle Harper spell check", noremap = true, silent = true })

-- jumping between errors
map("n", "]e", function()
	vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR })
end, { desc = "Next Error", noremap = true, silent = true })
map("n", "[e", function()
	vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR })
end, { desc = "Prev Error", noremap = true, silent = true })

-- Floating terminal setup
local floating_term = require("utils.floating-terminal")

-- Toggle lazygit
map("n", "<leader>gg", floating_term.toggle_lazygit, { desc = "Lazygit", noremap = true, silent = true })

-- Alternative keybinding (Ctrl+/) - some terminals send this as Ctrl+_
map("t", "<C-_>", function()
	floating_term.hide_all()
end, { desc = "Hide Terminal", noremap = true, silent = true })

-- Add keymap for some quick insertions
map("n", "<leader>id", function()
	vim.cmd("normal! a" .. os.date("%Y-%m-%d"))
end, { desc = "Insert Date", noremap = true, silent = true })

-- open notes.md from project root if exists
map("n", "<leader>on", function()
	local notes_path = vim.fn.getcwd() .. "/notes.md"
	if vim.fn.filereadable(notes_path) == 1 then
		-- Check if buffer is already open
		local bufnr = vim.fn.bufnr(notes_path)
		if bufnr ~= -1 then
			-- Buffer exists, check if it's in a window
			local winnr = vim.fn.bufwinnr(bufnr)
			if winnr ~= -1 then
				-- Buffer is in a window, focus it
				vim.cmd(winnr .. "wincmd w")
			else
				-- Buffer exists but not in any window, open it in current window
				vim.cmd.buffer(bufnr)
			end
		else
			-- Buffer doesn't exist, open the file
			vim.cmd.edit(notes_path)
		end
	else
		vim.notify("notes.md not found in project root", vim.log.levels.WARN)
	end
end, { desc = "Open Project Notes", noremap = true, silent = true })

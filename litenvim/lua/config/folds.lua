-- Custom folding scheme.

vim.opt.foldmethod = "manual"
vim.opt.foldlevel = 99 -- Start with all folds open
vim.opt.foldenable = true -- Enable folding
vim.opt.foldlevelstart = 99 -- Don't automatically close folds when opening a buffer
vim.opt.foldcolumn = "1" -- Show a column for folds
vim.opt.foldopen = "" -- Don't automatically open folds on any events

local function smart_fold_toggle()
	local line_num = vim.fn.line(".")
	if vim.fn.foldlevel(line_num) > 0 or vim.fn.foldclosed(line_num) ~= -1 then
		vim.cmd("normal! za")
	else
		local enter_key = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
		vim.api.nvim_feedkeys(enter_key, "n", true)
	end
end

-- Normal Mode: Toggle fold if on a fold, otherwise act as <CR>.
vim.keymap.set("n", "<CR>", smart_fold_toggle, { noremap = true, silent = true, desc = "Smart fold toggle" })

-- Visual Mode: Create a manual fold from the selected lines.
vim.keymap.set("v", "<CR>", "zf", { noremap = true, silent = true, desc = "Create manual fold from selection" })

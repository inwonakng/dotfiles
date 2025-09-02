-- Custom folding scheme.
-- Prioritize user-defined folds, then indent-based folds.
-- Pressing <CR> will toggle folds if on a foldable line, otherwise it will act as a normal <CR>.
-- In visual mode, pressing <CR> will create a fold from the selected lines.
-- To delete a fold, use 'zd' in normal mode (this is built in).

vim.opt.foldmethod = "indent"
vim.opt.foldlevel = 99 -- Start with all folds open
vim.opt.foldenable = true -- Enable folding
vim.opt.foldlevelstart = 99 -- Don't automatically close folds when opening a buffer
vim.opt.foldcolumn = "1" -- Show a column for folds

local function smart_fold_toggle()
	-- Get the line number of the cursor
	local line_num = vim.fn.line(".")
	if vim.fn.foldlevel(line_num) > vim.fn.foldlevel(line_num - 1) or vim.fn.foldclosed(line_num) ~= -1 then
		-- If the line is foldable or inside a closed fold, toggle it.
		-- 'za' is the standard command to toggle a fold at the cursor.
		vim.cmd("normal! za")
	else
		-- If the line is not foldable, execute the default <CR> action.
		-- We use feedkeys to do this safely without causing a recursive mapping.
		local enter_key = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
		vim.api.nvim_feedkeys(enter_key, "n", true)
	end
end

-- Normal Mode: Use our smart toggle function when <CR> is pressed.
vim.keymap.set("n", "<CR>", smart_fold_toggle, { noremap = true, silent = true, desc = "Smart fold toggle" })

-- Visual Mode: Create a manual fold for the selected lines when <CR> is pressed.
-- 'zf' is the command to create a fold from a visual selection.
vim.keymap.set("v", "<CR>", "zf", { noremap = true, silent = true, desc = "Create manual fold from selection" })

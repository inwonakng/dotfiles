vim.opt_local.textwidth = 80
vim.opt_local.formatoptions:remove('t')  -- Remove automatic text wrapping
vim.opt_local.formatoptions:append('c')  -- Wrap comments using textwidth
vim.opt_local.formatoptions:append('r')  -- Continue comments with the comment leader
-- vim.opt_local.formatoptions:append('q')
-- vim.opt_local.formatoptions:append('n')

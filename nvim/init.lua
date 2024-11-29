-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- for python
vim.g.python3_host_prog = "~/miniconda3/envs/pynvim/bin/python"
vim.o.termguicolors = true

-- vim.api.nvim_create_autocmd({ "VimEnter" }, {
--   group = vim.api.nvim_create_augroup("lazyvim_restore_session", { clear = true }),
--   callback = function()
--     local cwd = vim.fn.getcwd()
--     if cwd == vim.env.HOME then
--       return
--     end
--   end,
--   nested = true,
-- })

-- vim.api.nvim_create_autocmd({ "User" }, {
--   pattern = "PersistenceLoadPost",
--   callback = function()
--     vim.notify("post load!")
--   end,
-- })

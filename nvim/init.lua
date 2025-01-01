-- bootstrap lazy.nvim, LazyVim and your plugins

-- for python
vim.g.python3_host_prog = vim.env.PYTHON_DEFAULT_PATH .. "/python"
vim.o.termguicolors = true

require("config.lazy")

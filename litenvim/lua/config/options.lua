vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.g.have_nerd_font = false
vim.g.autoformat = false
vim.g.python3_host_prog = vim.env.PYTHON_DEFAULT_PATH .. "/python"
vim.g.markdown_recommended_style = 0
vim.g.sessionoptions = "buffers,curdir,folds,help,tabpages,winsize,terminal"

vim.filetype.add({
  extension = {
    mdx = 'markdown'
  }
})
vim.schedule(function()
  vim.opt.clipboard = "unnamedplus"
end)

vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.mouse = "a"
vim.opt.showmode = false
vim.opt.breakindent = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim.opt.inccommand = "split"
vim.opt.cursorline = true
vim.opt.scrolloff = 10
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.shiftwidth = 4
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.termguicolors = true

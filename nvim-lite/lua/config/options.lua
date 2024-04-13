-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.filetype.add({
  extension = {
    mdx = 'mdx'
  }
})

local opt = vim.opt

opt.linebreak = true
vim.diagnostic.config({
  underline = true,
  signs = true,
  virtual_text = false,
  float = {
    show_header = true,
    source = "always",
    border = "rounded",
    focusable = true,
  },
  update_in_insert = false, -- default to false
  severity_sort = false, -- default to false
})

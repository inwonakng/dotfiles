-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

local function augroup(name)
  return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
end

-- Fix conceallevel for markdown files
vim.api.nvim_create_autocmd({ "FileType" }, {
  group = augroup("md_conceal"),
  pattern = { "md", "mdx" },
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})

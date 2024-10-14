-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

local function augroup(name)
  return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
end

local fn = require("utils.fn")

-- Fix conceallevel for markdown files
vim.api.nvim_create_autocmd({ "FileType" }, {
  group = augroup("md_conceal"),
  pattern = { "md", "mdx" },
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})

-- -- Runs before quitting
-- vim.api.nvim_create_autocmd("VimLeavePre", {
--   pattern = "*",
--   callback = function()
--     if fn.directory_exists(".obsidian") then
--       fn.git_commit_and_push(".")
--     end
--   end,
-- })

-- Runs when opening
vim.api.nvim_create_autocmd("VimEnter", {
  pattern = "*",
  callback = function()
    fn.git_pull(".")
  end,
})

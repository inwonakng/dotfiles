-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

local fn = require("utils.fn")

-- NOTE: this file is ran after VimEnter, so I will just place this on top here.

-- if vim.fn.getcwd() ~= vim.env.HOME then
--   require("persistence").load()
-- end
--
-- -- Fix conceallevel for markdown files
-- vim.api.nvim_create_autocmd({ "FileType" }, {
--   group = vim.api.nvim_create_augroup("lazyvim_md_conceal", { clear = true }),
--   pattern = { "md", "mdx" },
--   callback = function()
--     vim.opt_local.conceallevel = 0
--   end,
-- })

vim.api.nvim_create_autocmd({ "FileType" }, {
  group = vim.api.nvim_create_augroup("lazyvim_vimtex_conceal", { clear = true }),
  pattern = { "bib", "tex" },
  callback = function()
    vim.opt_local.conceallevel = 0
    -- vim.opt_local.textwidth = 80
    vim.opt_local.wrap = true
  end,
})

-- Obsidian with hledger. If in this directory, render as ledger filetype
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = vim.api.nvim_create_augroup("lazyvim_md_ledger", { clear = true }),
  pattern = vim.env.HOME .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal/finance/journals/**.md",
  callback = function()
    vim.bo.filetype = "ledger"
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.keymap.set("n", "<leader>cf", ":LedgerAlignBuffer<cr>", { desc = "Format buffer", buffer = 0 })
  end,
})

-- Turn off minipairs in command line
vim.api.nvim_create_autocmd("CmdlineEnter", {
  group = vim.api.nvim_create_augroup("lazyvim_minipairs_disable", { clear = true }),
  pattern = "*",
  callback = function()
    vim.b.minipairs_disable = true
  end,
})

-- But turn it back on when leaving command line
vim.api.nvim_create_autocmd("CmdlineLeave", {
  group = vim.api.nvim_create_augroup("lazyvim_minipairs_enable", { clear = true }),
  pattern = "*",
  callback = function()
    vim.b.minipairs_disable = false
  end,
})

-- vim.api.nvim_create_autocmd({ "User" }, {
--   pattern = "PersistenceLoadPost",
--   callback = function()
--     vim.notify("post load!")
--   end,
-- })
--
-- vim.api.nvim_create_autocmd({ "VimEnter" }, {
--   group = vim.api.nvim_create_augroup("lazyvim_restore_session", { clear = true }),
--   callback = function()
--     -- print("vimetner")
--     -- vim.notify("I want to restore!")
--     if vim.fn.getcwd() ~= vim.env.HOME then
--       require("persistence").load()
--     end
--   end,
--   nested = true,
-- })

-- Change filetype for aichat
vim.api.nvim_create_augroup("ChangeFiletypeOnPattern", { clear = true })

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = "/private/var/folders/*/aichat-*.txt",
    group = "ChangeFiletypeOnPattern",
    command = "set filetype=markdown"
})

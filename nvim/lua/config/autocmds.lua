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

-- Obsidian with hledger. If in this directory, render as ledger filetype
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = os.getenv("HOME")
    .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal/finance/journals/**.md",
  callback = function()
    vim.bo.filetype = "ledger"
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.keymap.set("n", "<leader>cf", ":LedgerAlignBuffer<cr>", { desc = "Format buffer" })
  end,
})

vim.api.nvim_create_autocmd({ "FileType" }, {
  group = vim.api.nvim_create_augroup("lazyvim_vimtex_conceal", { clear = true }),
  pattern = { "bib", "tex" },
  callback = function()
    vim.opt_local.conceallevel = 0
    -- vim.opt_local.textwidth = 80
    vim.opt_local.wrap = true
  end,
})

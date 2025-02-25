-- latex is special
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "bib", "tex" },
  callback = function()
    vim.opt_local.conceallevel = 0
    vim.opt_local.wrap = true
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
  end,
})

-- filetypes that use 2 spaces for tab
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "lua", "javascript", "typescript", "json", "html", "css", "scss", "yaml", "markdown" },
  callback = function()
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
  end,
})

-- Obsidian with hledger. If in this directory, render as ledger filetype
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = vim.api.nvim_create_augroup("md_ledger", { clear = true }),
  pattern = vim.env.HOME .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal/finance/journals/**.md",
  callback = function()
    vim.bo.filetype = "ledger"
    vim.opt_local.wrap = false
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.keymap.set("n", "<leader>cf", "<cmd>LedgerAlignBuffer<cr>", { desc = "Format buffer", buffer = 0 })
  end,
})

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

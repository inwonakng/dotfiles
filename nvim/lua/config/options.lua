-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- In case you don't want to use `:LazyExtras`,
-- then you need to set the option below.
vim.g.lazyvim_picker = "fzf"
vim.g.lazyvim_python_lsp = "basedpyright"
vim.g.lazyvim_python_ruff = "ruff"
-- Set to "ruff_lsp" to use the old LSP implementation version.

vim.g.autoformat = false

vim.filetype.add({
  extension = {
    mdx = 'markdown'
  }
})

vim.opt.linebreak = true
vim.opt.breakindent = true

-- vim.diagnostic.config({
--   underline = true,
--   signs = true,
--   virtual_text = false,
--   float = {
--     show_header = true,
--     source = "always",
--     border = "rounded",
--     focusable = true,
--   },
--   update_in_insert = false, -- default to false
--   severity_sort = false, -- default to false
-- })

-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map("n", "<leader>p", function()
  require("nabla").popup()
end, { desc = "render latex equation" })

-- Resize window using <ctrl> and shift
map("n", "<C-S-k>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-S-j>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-S-h>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-S-l>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })


-- Open diagnostic in floating window
map("n", "<leader>i", ":lua vim.diagnostic.open_float(nil, {focus=false, scope='cursor'})<CR>", { desc = 'Toggle Diagnostics' })

-- compile latex file
map("n", "<leader>cC", ":VimtexCompile<CR>", { desc = "Compile LaTex document" })

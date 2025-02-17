-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set
local del = vim.keymap.del

-- Resize window using <ctrl> and shift
-- map("n", "<C-S-k>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
-- map("n", "<C-S-j>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
-- map("n", "<C-S-h>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })
-- map("n", "<C-S-l>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })

-- from https://www.reddit.com/r/neovim/comments/187q160/togglehomezero_keymap/
-- use 0 to do both ^ and 0
-- map("n", "0", function()
--   if vim.fn.reg_recording() ~= "" then
--     vim.api.nvim_feedkeys("0", "n", true)
--   else
--     local pos = vim.fn.col(".")
--     if pos == 1 then
--       vim.api.nvim_feedkeys("^", "n", true)
--     elseif pos == vim.fn.col("$") - 1 then
--       vim.api.nvim_feedkeys("0", "n", true)
--     else
--       vim.api.nvim_feedkeys("$", "n", true)
--     end
--   end
-- end, { desc = "smart zero movement" })

del("n", "<C-w>d")
map("n", "<leader>wd", "<cmd>q<cr>", { desc = "Close Window" })

-- disabled bufferline, using bo to close all other buffers
map("n", "<leader>bo", function()
  local bufs = vim.api.nvim_list_bufs()
  -- local current_buf = vim.api.nvim_get_current_buf()
  local non_hidden_buffer = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    non_hidden_buffer[vim.api.nvim_win_get_buf(win)] = true
  end
  for _, i in ipairs(bufs) do
    if non_hidden_buffer[i] == nil then
      vim.api.nvim_buf_delete(i, {})
    end
  end
end, { desc = "delete hidden buffers" })

-- close all other windows
-- map("n", "<leader>wo", function()
--   local wins = vim.api.nvim_list_wins()
--   for _, i in ipairs(wins) do
--     if i ~= vim.api.nvim_get_current_win() then
--       vim.api.nvim_win_hide(i)
--     end
--   end
-- end, { desc = "delete hidden buffers" })

-- -- undo lazyvim keybinds
-- del("t", "<esc><esc>")
-- -- del("n", "<leader>w|")
del("n", "<leader>|")
-- del("n", "<leader>-")
--
-- remap window split key from lazyvim
map("n", "<leader>\\", "<C-W>v", { desc = "Split Window Right", remap = true })

map("n", "<leader>C", ":norm gc<cr>", { desc = "Comment" })
map("n", "<leader>cc", ":norm gcc<cr>", { desc = "Comment Line" })
map("x", "<leader>cc", ":vi v_gc<cr>", { desc = "Comment Selection" })

map("n", "yP", ":YankFilePath<CR>", { noremap = true, silent = true })
map("n", "yp", ":YankRelativeFilePath<CR>", { noremap = true, silent = true })

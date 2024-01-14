-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- Resize window using <ctrl> and shift
map("n", "<C-S-k>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-S-j>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-S-h>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-S-l>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- map("n", "<leader>r", "<cmd>Telescope resume<cr>", { desc = "Resume previous search" })

-- from https://www.reddit.com/r/neovim/comments/187q160/togglehomezero_keymap/
-- use 0 to do both ^ and 0
map('n', '0', 
  function() 
    if vim.fn.reg_recording() ~= "" then 
      vim.api.nvim_feedkeys('0', 'n', true)
    else 
      local pos = vim.fn.col('.')
      if pos == 1 then 
        vim.api.nvim_feedkeys('^', 'n', true)
      elseif pos == vim.fn.col('$') - 1 then 
        vim.api.nvim_feedkeys('0', 'n', true)
      else vim.api.nvim_feedkeys('$', 'n', true)
      end 
    end
  end,
  { desc = 'smart zero movement' }
)

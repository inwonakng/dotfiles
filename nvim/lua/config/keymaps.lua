-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- Resize window using <ctrl> and shift
map("n", "<C-S-k>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-S-j>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-S-h>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })
map("n", "<C-S-l>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })

-- map("n", "<leader>r", "<cmd>Telescope resume<cr>", { desc = "Resume previous search" })

-- from https://www.reddit.com/r/neovim/comments/187q160/togglehomezero_keymap/
-- use 0 to do both ^ and 0
map("n", "0", function()
  if vim.fn.reg_recording() ~= "" then
    vim.api.nvim_feedkeys("0", "n", true)
  else
    local pos = vim.fn.col(".")
    if pos == 1 then
      vim.api.nvim_feedkeys("^", "n", true)
    elseif pos == vim.fn.col("$") - 1 then
      vim.api.nvim_feedkeys("0", "n", true)
    else
      vim.api.nvim_feedkeys("$", "n", true)
    end
  end
end, { desc = "smart zero movement" })

-- Override telescop lsp navigation for fzf-lua
-- map("n", "<gr>", "<cmd>lua require('fzf-lua').lsp_references()<cr>", { silent = true })
-- map("n", "<gd>", "<cmd>lua require('fzf-lua').lsp_definitions()<cr>", { silent = true })

-- Override lazyvim behavior to use kitty navigation
vim.g.kitty_navigator_no_mappings = 1

map("n", "<C-h>", ":KittyNavigateLeft<cr>", { silent = true })
map("n", "<C-l>", ":KittyNavigateRight<cr>", { silent = true })
map("n", "<C-j>", ":KittyNavigateDown<cr>", { silent = true })
map("n", "<C-k>", ":KittyNavigateUp<cr>", { silent = true })

-- vim-tmux-navigator
if os.getenv("TMUX") then
  map("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>")
  map("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>")
  map("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>")
  map("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>")
  map("n", "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>")
end


-- Backspace to go back to previous file
-- map("n", "<bs>", ":e #<cr>", {silent=true})

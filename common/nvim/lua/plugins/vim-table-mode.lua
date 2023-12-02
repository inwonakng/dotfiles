return {
  "dhruvasagar/vim-table-mode",
  init = function ()
    vim.g["table_mode_corner"] = "|"
    vim.g["table_mode_syntax"] = 0
  end,
  -- keys = { 
  --   { "<leader>tm", "<C-U>call tablemode#Toggle()", desc = "Toggle table mode" },
  --   { "<leader>tt", "<Plug>(table-mode-tableize)", desc = "Tableize" },
  --   { "<leader>tr", "<cmd>TableModeRealign<cr>", desc = "Realign table" },
  --   { "<leader>ts", "<cmd>TableSort<cr>", desc = "Sort table" },
  --   { "<leader>t?", "<Plug>(table-mode-echo-cell)", desc = "Echo Cell" },
  --   { "<leader>tdc", "<Plug>(table-mode-delete-column)", desc = "Delete column" },
  --   { "<leader>tdr", "<Plug>(table-mode-delete-row)", desc = "Delete Row" },
  --   { "<leader>tfa", "<Plug>(table-mode-add-formula)", desc = "Add formula" },
  --   { "<leader>tfe", "<Plug>(table-mode-eval-formula)", desc = "Evaluate formula" },
  --   { "<leader>tic", "<Plug>(table-mode-insert-column-before)", desc = "Insert column before" },
  --   { "<leader>tiC", "<Plug>(table-mode-insert-column-after)", desc = "Insert column after" },
  -- },
}

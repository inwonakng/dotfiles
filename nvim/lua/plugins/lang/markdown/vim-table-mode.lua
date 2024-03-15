return {
  "dhruvasagar/vim-table-mode",
  init = function()
    vim.g["table_mode_corner"] = "|"
    vim.g["table_mode_syntax"] = 0
    vim.g["table_mode_syntax"] = 0
    vim.g["table_mode_disable_mappings"] = 1
  end,
  keys = {
    { "<leader>tm", "<cmd>TableModeToggle<cr>", desc = "Toggle Table Mode" },
    { "<leader>tdc", "<cmd>TableModeToggle<cr>", desc = "Toggle Table Mode" },
  },
}

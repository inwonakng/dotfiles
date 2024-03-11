return {
  "akinsho/git-conflict.nvim",
  version = "*",
  config = true,
  keys = {
    {"<leader>gcr", "<cmd>GitConflictRefresh<cr>", desc="Refresh Git conflicts"},
    -- {"<leader>gct", "<cmd>GitConflictRefresh<cr>", desc="Refresh Git conflicts"},
  }
}

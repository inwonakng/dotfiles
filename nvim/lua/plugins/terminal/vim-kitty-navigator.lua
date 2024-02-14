return {
  "knubie/vim-kitty-navigator",
  lazy = false,
  keys = {
    { "<C-h>", "<cmd><C-U>KittyNavigateLeft<cr>" },
    { "<C-l>", "<cmd><C-U>KittyNavigateRight<cr>" },
    { "<C-j>", "<cmd><C-U>KittyNavigateDown<cr>" },
    { "<C-k>", "<cmd><C-U>KittyNavigateUp<cr>" },
  },
}
-- map("n", "<C-h>", ":KittyNavigateLeft<cr>", { silent = true })
-- map("n", "<C-l>", ":KittyNavigateRight<cr>", { silent = true })
-- map("n", "<C-j>", ":KittyNavigateDown<cr>", { silent = true })
-- map("n", "<C-k>", ":KittyNavigateUp<cr>", { silent = true })

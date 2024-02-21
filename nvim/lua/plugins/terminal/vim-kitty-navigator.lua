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

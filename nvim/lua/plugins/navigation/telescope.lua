return {
  "nvim-telescope/telescope.nvim",
  keys = {
    { "<leader>r", "<cmd>Telescope resume<cr>", desc = "Resume previous search" },
    {
      "<leader><space>",
      "<cmd>lua require'telescope.builtin'.find_files({ find_command = {'rg', '--files', '--hidden', '-g', '!.git' }})<cr>",
      desc = "Resume previous search",
    },
  },
}

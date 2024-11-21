return {
  -- slime (REPL integration)
  {
    "jpalardy/vim-slime",
    keys = {
      { "<leader>r", "", desc = "+vim-slime" },
      { "<leader>rc", "<CMD>SlimeConfig<CR>", desc = "Slime Config" },
      -- { "<leader>rr", "<Plug>SlimeSendCell<BAR>/^# %%<CR>", desc = "Slime Send Cell" },
      { "<leader>rr", "<Plug>SlimeSendCell<CR>", desc = "Slime Send Cell" },
      { "<leader>rr", ":<C-u>'<,'>SlimeSend<CR>", mode = "v", desc = "Slime Send Selection" },
      { "<leader>rn", "o# %%<ESC>o<ESC>D", desc = "Sime Insert New Cell" },
      { "]r", "/# %%<CR>", desc = "Sime Next Cell" },
      { "[r", "/# %%<CR>N", desc = "Sime Previous Cell" },

    },
    config = function()
      vim.g.slime_no_mappings = 1
      vim.g.slime_target = "wezterm"
      vim.g.slime_cell_delimiter = "# %%"
      vim.g.slime_bracketed_paste = 1
      vim.g.slime_python_ipython = 0
    end,
  },
}

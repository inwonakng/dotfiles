return {
  -- slime (REPL integration)
  {
    "jpalardy/vim-slime",
    keys = {
      { "<leader>rc", "<CMD>SlimeConfig<CR>", desc = "Slime Config" },
      { "<leader>rr", "<Plug>SlimeSendCell<BAR>/^#%%<CR>", desc = "Slime Send Cell" },
      { "<leader>rr", ":<C-u>'<,'>SlimeSend<CR>", mode = "v", desc = "Slime Send Selection" },
    },
    config = function()
      vim.g.slime_no_mappings = 1
      vim.g.slime_target = "wezterm"
      vim.g.slime_cell_delimiter = "#%%"
      vim.g.slime_bracketed_paste = 1
      vim.g.slime_python_ipython = 1
    end,
  },
}

return {
  "ibhagwan/fzf-lua",
  -- optional for icon support
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    -- calling `setup` is optional for customization
    require("fzf-lua").setup({})
  end,
  keys = {
    { "<leader>r", "<cmd>lua require('fzf-lua').resume()<cr>", desc = "Resume previous search" },
    {
      "<leader><space>",
      "<cmd>lua require('fzf-lua').files()<cr>",
      desc = "Search Files",
    },
    {
      "<leader>/",
      "<cmd>lua require('fzf-lua').grep()<cr>",
      desc = "Search File Contents",
    },
    {
      "<leader>sb",
      "<cmd>lua require('fzf-lua').buffers()<cr>",
      desc = "Search Buffers",
    },
    {
      "<leader>ss",
      "<cmd>lua require('fzf-lua').builtin()<cr>",
      desc = "fzf-lua Built-in Commands",
    },
    {
      "<leader>sm",
      "<cmd>lua require('fzf-lua').tmux_buffers()<cr>",
      desc = "List Tmux paste buffers",
    },
    {
      "<leader>dd",
      "<cmd>lua require('fzf-lua').dap_commands()<cr>",
      desc = "Debugger Commands",
    },
  }
}

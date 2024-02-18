local fzf_winopts = require("utils.fzf_winopts")

return {
  "ibhagwan/fzf-lua",
  -- optional for icon support
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    -- calling `setup` is optional for customization
    require("fzf-lua").setup({})
  end,
  keys = {
    {
      "<leader>r",
      function()
        require("fzf-lua").resume()
      end,
      desc = "Resume previous search",
    },
    {
      "<leader><space>",
      function()
        require("fzf-lua").files()
      end,
      desc = "Search Files",
    },
    {
      "<leader>/",
      function()
        require("fzf-lua").grep()
      end,
      desc = "Search File Contents",
    },
    {
      "<leader>sb",
      function()
        require("fzf-lua").buffers()
      end,
      desc = "Search Buffers",
    },
    {
      "<leader>ss",
      function()
        require("fzf-lua").builtin()
      end,
      desc = "fzf-lua Built-in Commands",
    },
    {
      "<leader>sm",
      function()
        require("fzf-lua").tmux_buffers()
      end,
      desc = "List Tmux Paste Buffers",
    },
    {
      "<leader>sl",
      function()
        require("fzf-lua").lsp_finder({ winopts = fzf_winopts.large.vertical })
      end,
      desc = "View LSP finder",
    },
    {
      "<leader>dd",
      function()
        require("fzf-lua").dap_commands()
      end,
      desc = "Debugger Commands",
    },
  },
}

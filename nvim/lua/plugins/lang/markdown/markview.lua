return {
  "OXY2DEV/markview.nvim",
  lazy = false, -- Recommended
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    list_items = {
      marker_minus = {
        add_padding = false,
      },
      marker_plus = {
        add_padding = false,
      },
      marker_star = {
        add_padding = false,
      },
      --- n. Items
      marker_dot = {
        add_padding = false,
      },
      --- n) Items
      marker_parenthesis = {
        add_padding = false,
      },
    },
    latex = {
      enable = true,
      block = {
        enable = true,
      },
      inline = {
        enable = true,
      },
      operators = {
        enable = true,
      },
      symbols = {
        enable = true,
      },
      subscript = {
        enable = true,
      },
      superscript = {
        enable = true,
      },
    },
  },
}
return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    -- code = {
    --   sign = false,
    --   width = "block",
    --   right_pad = 1,
    -- },
    heading = {
      sign = false,
      -- icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
    },
    callout = {
      motivation = { raw = "[!MOTIVATION]", rendered = " Motivation", highlight = "RenderMarkdownInfo" },
      intuition = { raw = "[!INTUITION]", rendered = " Intuition", highlight = "RenderMarkdownSuccess" },
      setting = { raw = "[!SETTING]", rendered = "󱊍 Setting", highlight = "RenderMarkdownHint" },
      image = { raw = "[!IMAGE]", rendered = " Image", highlight = "RenderMarkdownInfo" },
      table = { raw = "[!TABLE]", rendered = " Table", highlight = "RenderMarkdownInfo" },
    },
    latex = { enabled = true },
  },
}

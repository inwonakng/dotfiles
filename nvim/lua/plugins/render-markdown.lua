return {
  "MeanderingProgrammer/render-markdown.nvim",
  opts = {
    heading = {
      sign = true,
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
    },
    callout = {
      motivation = { raw = "[!MOTIVATION]", rendered = " Motivation", highlight = "RenderMarkdownInfo" },
      intuition = { raw = "[!INTUITION]", rendered = " Intuition", highlight = "RenderMarkdownSuccess" },
      setting = { raw = "[!SETTING]", rendered = "󱊍 Setting", highlight = "RenderMarkdownHint" },
      image = { raw = "[!IMAGE]", rendered = " Image", highlight = "RenderMarkdownInfo" },
      table = { raw = "[!TABLE]", rendered = " Table", highlight = "RenderMarkdownInfo" },
    },
    latex = { enabled = false },
    -- win_options = {
    --   conceallevel = {
    --     default = vim.api.nvim_get_option_value("conceallevel", {}),
    --     rendered = 2, -- <- especially this, so that both plugins play nice
    --   },
    -- },
    -- on = {
    --   attach = function()
    --     require("nabla").enable_virt({ autogen = true })
    --   end,
    -- },
    -- bullet = {
    --   icons = { "●", "○", "◆", "◇" },
    --   ordered_icons = function(level, index, value)
    --     value = vim.trim(value)
    --     local value_index = tonumber(value:sub(1, #value - 1))
    --     return string.format("%d.", value_index > 1 and value_index or index)
    --   end,
    -- },
  },
}

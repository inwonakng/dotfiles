return {
  "zbirenbaum/copilot.lua",
  lazy = false,
  cmd = "Copilot",
  build = ":Copilot auth",
  opts = {
    suggestion = {
      -- enabled = false,
      enabled = true,
      -- auto_trigger = true,
      keymap = { accept = "<C-a>" },
    },
    panel = {
      enabled = false,
      -- enabled = true,
      -- auto_refresh = false,
      -- keymap = {
      --   jump_prev = "[[",
      --   jump_next = "]]",
      --   accept = "<CR>",
      --   refresh = "gr",
      --   open = "<C-CR>",
      -- },
      -- layout = {
      --   position = "bottom", -- | top | left | right
      --   ratio = 0.4,
      -- },
    },
    filetypes = {
      markdown = true,
      help = true,
    },
  },
}

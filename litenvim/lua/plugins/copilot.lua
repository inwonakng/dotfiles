return {
  "zbirenbaum/copilot.lua",
  -- lazy = false,
  -- this is the way I set node path in bashrc, so if this is null, assume that
  -- we don't have node.
  event = "InsertEnter",
  enabled = vim.env.NODE_DEFAULT_PATH ~= nil,
  cmd = "Copilot",
  build = ":Copilot auth",
  opts = {
    suggestion = {
      enabled = true,
      auto_trigger = true,
      keymap = { accept = "<C-a>" },
    },
    panel = {
      enabled = false,
    },
    filetypes = {
      markdown = true,
      help = true,
    },
  },
}

return {
  "nvim-pack/nvim-spectre",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "grapp-dev/nui-components.nvim",
  },
  build = false,
  cmd = "Spectre",
  -- enabled = false,
  opts = {
    open_cmd = "noswapfile vnew",
  },
  -- stylua: ignore
  keys = {
    { "<leader>sr", 
      function()
        local w = require("plugins.ui.pickers.spectre")
        w.toggle()
      end,
      desc = "Test NuiComponents",
    },
  },
}

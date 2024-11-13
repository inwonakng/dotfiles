return {
  "MeanderingProgrammer/render-markdown.nvim",
  enabled=false,
  dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.nvim" }, -- if you use the mini.nvim suite
  opts = {
    bullet = {
      right_pad = 1,
    },
    log_level = "debug",
    latex = {
      enabled = true,
    },
  },
}

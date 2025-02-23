return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = function(_, opts)
    opts.options.section_separators  = { left = "", right = "" }
    opts.options.component_separators  = ""
    opts.options.globalstatus = true
    opts.options.disabled_filetypes = { statusline = { "dashboard", "alpha", "starter" } }
    return opts
  end,
}

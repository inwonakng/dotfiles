return {
  "williamboman/mason.nvim",
  opts = function(_, opts)
    vim.list_extend(opts.ensure_installed, {
      "black",
      "shfmt",
      "markdownlint",
      -- "marksman",
      "prettier",
      "stylua",
      "ruff",
      "basedpyright",
      "codelldb"
    })
  end,
}

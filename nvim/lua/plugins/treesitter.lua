return {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    vim.treesitter.language.register("markdown", "mdx")
    -- vim.list_extend(opts.highlight.disable, { "tsx" })
    if type(opts.ensure_installed) == "table" then
      vim.list_extend(opts.ensure_installed, {
        "markdown",
        "markdown_inline",
        "bibtex",
        "latex",
        "ninja",
        "python",
        "ron",
        "rst",
        "toml",
        "typescript",
        "tsx",
        "json",
        "json5",
        "jsonc",
        "ledger",
        "rust",
        "ron",
      })
    end
    opts.highlight = opts.highlight or {}
    if type(opts.ensure_installed) == "table" then
      vim.list_extend(opts.ensure_installed, { "bibtex" })
    end
    if type(opts.highlight.disable) == "table" then
      vim.list_extend(opts.highlight.disable, { "latex" })
    else
      opts.highlight.disable = { "latex" }
    end
    opts.autotag = {
      enable = true,
      filetypes = { "ts", "tsx", "js", "jsx", "mdx", "html" },
    }
  end,
}

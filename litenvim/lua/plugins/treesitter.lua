return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
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
    },
    highlight = {
      disable = { "latex" },
    },
    autotag = {
      enable = true,
      filetypes = { "ts", "tsx", "js", "jsx", "mdx", "html" },
    },
  },
}

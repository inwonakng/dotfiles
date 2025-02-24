return {
  "nvim-treesitter/nvim-treesitter",
  -- init = function(plugin)
  --   -- NOTE: i copied this from lazyvim, not sure if actually needed.
  --   -- PERF: add nvim-treesitter queries to the rtp and it's custom query predicates early
  --   -- This is needed because a bunch of plugins no longer `require("nvim-treesitter")`, which
  --   -- no longer trigger the **nvim-treesitter** module to be loaded in time.
  --   -- Luckily, the only things that those plugins need are the custom queries, which we make available
  --   -- during startup.
  --   require("lazy.core.loader").add_to_rtp(plugin)
  --   require("nvim-treesitter.query_predicates")
  -- end,
  opts_extend = { "ensure_installed" },
  opts = {
    ensure_installed = {
      "c",
      "lua",
      "vim",
      "vimdoc",
      "query",
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
      enable = true,
      disable = { "latex" },
    },
    autotag = {
      enable = true,
      filetypes = { "ts", "tsx", "js", "jsx", "mdx", "html" },
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "<C-space>",
        node_incremental = "<C-space>",
        scope_incremental = false,
        node_decremental = "<bs>",
      },
    },
  },
  -- NOTE: we need to call this!! otherwise the treesitter queries won't be available
  config = function(_, opts)
    require("nvim-treesitter.configs").setup(opts)
  end,
}

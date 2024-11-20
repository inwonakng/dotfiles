-- NOTE:  syntax error when using snippets: https://github.com/Saghen/blink.cmp/issues/295
-- It's setting syntax type to markdown for some reason, I manually changed it for now.
return {
  "saghen/blink.cmp",
  -- lazy = false, -- lazy loading handled internally
  dependencies = { "rafamadriz/friendly-snippets", "saghen/blink.compat" },
  -- dependencies = { "rafamadriz/friendly-snippets" },
  version = not vim.g.lazyvim_blink_main and "*",
  build = vim.g.lazyvim_blink_main and "cargo build --release",
  -- allows extending the enabled_providers array elsewhere in your config
  -- without having to redefining it
  opts_extend = { "sources.completion.enabled_providers", "sources.compat" },
  config = function(_, opts)
    -- setup compat sources
    local enabled = opts.sources.completion.enabled_providers
    for _, source in ipairs(opts.sources.compat or {}) do
      opts.sources.providers[source] = vim.tbl_deep_extend(
        "force",
        { name = source, module = "blink.compat.source" },
        opts.sources.providers[source] or {}
      )
      if type(enabled) == "table" and not vim.tbl_contains(enabled, source) then
        table.insert(enabled, source)
      end
    end
    require("blink.cmp").setup(opts)
  end,
  opts = {
    keymap = {
      ["<S-CR>"] = { "hide" },
      ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<C-CR>"] = { "select_and_accept" },
      ["<C-n>"] = { "select_next", "fallback" },
      ["<C-p>"] = { "select_prev", "fallback" },
      ["<C-b>"] = { "scroll_documentation_up", "fallback" },
      ["<C-f>"] = { "scroll_documentation_down", "fallback" },
    },
    nerd_font_variant = "mono",
    highlight = {
      use_nvim_cmp_as_default = false,
    },
    windows = {
      documentation = {
        min_width = 15,
        max_width = 50,
        max_height = 15,
        border = vim.g.borderStyle,
        auto_show = true,
        auto_show_delay_ms = 500,
      },
      autocomplete = {
        min_width = 10,
        max_height = 10,
        border = vim.g.borderStyle,
        -- selection = "auto_insert", -- PENDING https://github.com/Saghen/blink.cmp/issues/117
        selection = "preselect",
        -- cycle = { from_top = true },
        cycle = { from_top = true, from_bottom = true },
      },
    },
    accept = { auto_brackets = { enabled = true } },
    sources = {
      compat = {},
      completion = {
        -- enabled_providers = { "lsp", "path", "snippets", "buffer", "obsidian", "obsidian_tags", "obsidian_new" },
        enabled_providers = { "lsp", "path", "snippets", "buffer" },
      },
    },
    kind_icons = LazyVim.config.icons.kinds,
  },
}

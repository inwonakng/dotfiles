return {
  "saghen/blink.cmp",
  -- lazy = false, -- lazy loading handled internally
  dependencies = { "saghen/blink.compat", "L3MON4D3/LuaSnip" },
  -- dependencies = { "rafamadriz/friendly-snippets" },
  version = not vim.g.lazyvim_blink_main and "*",
  build = vim.g.lazyvim_blink_main and "cargo build --release",
  -- allows extending the enabled_providers array elsewhere in your config
  -- without having to redefining it
  opts_extend = { "sources.default" },
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
    appearance = {
      nerd_font_variant = "mono",
      kind_icons = LazyVim.config.icons.kinds,
      use_nvim_cmp_as_default = false,
    },
    completion = {
      documentation = {
        window = {
          min_width = 15,
          max_width = 50,
          max_height = 15,
          border = vim.g.borderStyle,
        },
        auto_show = true,
      },
      list = {
        selection = "preselect",
        cycle = { from_top = true, from_bottom = true },
      },
    },
    sources = {
      default = { "lsp", "path", "luasnip", "buffer" },
    },
    snippets = {
      expand = function(snippet)
        require("luasnip").lsp_expand(snippet)
      end,
      active = function(filter)
        if filter and filter.direction then
          return require("luasnip").jumpable(filter.direction)
        end
        return require("luasnip").in_snippet()
      end,
      jump = function(direction)
        require("luasnip").jump(direction)
      end,
    },
  },
}

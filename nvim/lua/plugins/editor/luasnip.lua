return {
  "L3MON4D3/LuaSnip",
  lazy = true,
  build = (not LazyVim.is_win())
      and "echo 'NOTE: jsregexp is optional, so not a big deal if it fails to build'; make install_jsregexp"
    or nil,
  dependencies = { "rafamadriz/friendly-snippets" },
  opts = function(_, opts)
    local ls = require("luasnip")
    local luasnip_loader = require("luasnip.loaders.from_vscode")
    luasnip_loader.lazy_load({ paths = { "./snippets" } })
    luasnip_loader.lazy_load()

    opts[history] = true
    opts[delete_check_events] = "TextChanged"
    -- history = true,
    -- delete_check_events = "TextChanged",
    return opts
  end,
}

return {
  "L3MON4D3/LuaSnip",
  dependencies = {
    "rafamadriz/friendly-snippets",
  },
  opts = {
    history = true,
    delete_check_events = "TextChanged",
  },
  config = function()
    local luasnip_loader = require("luasnip.loaders.from_vscode")
    luasnip_loader.lazy_load({ paths = { "./snippets" }})
    luasnip_loader.lazy_load()
  end,
}

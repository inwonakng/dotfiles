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
    local ls = require("luasnip")
    local luasnip_loader = require("luasnip.loaders.from_vscode")
    luasnip_loader.lazy_load({ paths = { "./snippets" } })
    luasnip_loader.lazy_load()

    vim.keymap.set({ "i", "s" }, "<C-n>", function()
      ls.jump(1)
    end, { silent = true })
    vim.keymap.set({ "i", "s" }, "<C-p>", function()
      ls.jump(-1)
    end, { silent = true })

    vim.keymap.set({ "i", "s" }, "<C-s>", function()
      if ls.choice_active() then
        ls.change_choice(1)
      end
    end, { silent = true })
  end,
}

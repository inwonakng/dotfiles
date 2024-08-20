return {
  "hrsh7th/nvim-cmp",
  dependencies = {
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "zbirenbaum/copilot-cmp",
    "hrsh7th/cmp-nvim-lsp",
    "saadparwaiz1/cmp_luasnip",
    "hrsh7th/cmp-omni",
    "Saecki/crates.nvim",
    "onsails/lspkind.nvim",
    "kirasok/cmp-hledger",
  },
  event = "InsertEnter",
  opts = function(_, opts)
    -- vim.api.nvim_set_hl(0, "CmpGhostText", { link = "Comment", default = true })
    local cmp = require("cmp")
    -- local defaults = require("cmp.config.default")()
    local compare = require("cmp.config.compare")

    -- table.insert(opts.sources, 1, {
    -- name = "copilot",
    -- group_index = 1,
    -- priority = 100,
    -- })
    -- vim.

    opts.window = {
      completion = cmp.config.window.bordered({
        col_offset = -3,
        side_padding = 0,
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
      }),
      documentation = cmp.config.window.bordered({
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
      }),
    }

    opts.sources = cmp.config.sources({
      { name = "nvim_lsp", priority = 20, group = 1 },
      -- { name = "crates", priority = 20, group = 1 },
      { name = "vimtex", priority = 15, group = 1 },
      { name = "path", priority = 10, group = 1 },
      { name = "buffer", priority = 10, group = 1 },
      { name = "omni", priority = 9 },
      { name = "luasnip", priority = 9, group = 1 },
      { name = "hledger", priority = 6, group = 1 },
      { name = "copilot", priority = 6 },
      -- { name = "codeium", priority = 6 },
    })

    -- opts.snippet = {
    -- expand = function(args)
    -- require("luasnip").lsp_expand(args.body)
    -- end,
    -- }

    return opts
  end,
  -- config = function(_, opts)
  -- for _, source in ipairs(opts.sources) do
  -- source.group_index = source.group_index or 1
  -- end
  -- require("cmp").setup(opts)
  -- end,
}

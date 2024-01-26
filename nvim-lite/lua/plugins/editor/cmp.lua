return {
  "hrsh7th/nvim-cmp",
  dependencies = {
    -- "zbirenbaum/copilot-cmp",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "saadparwaiz1/cmp_luasnip",
    "hrsh7th/cmp-omni",
  },
  opts = function(_, opts)
    local cmp = require("cmp")
    local compare = require("cmp.config.compare")
    return {
      window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
      },
      enabled = function()
        local disabled = false
        disabled = disabled or (vim.api.nvim_buf_get_option(0, "buftype") == "prompt")
        -- disabled = disabled or (vim.fn.reg_recording() ~= '')
        -- disabled = disabled or (vim.fn.reg_executing() ~= '')
        return not disabled
      end,
      sources = cmp.config.sources({
        { name = "nvim_lsp", priority = 10 },
        { name = "omni", priority = 9 },
        { name = "luasnip", priority = 9 },
      }, {
        -- { name = "copilot", priority = 6 },
        { name = "path", priority = 5 },
        { name = "buffer", priority = 5 },
      }),
      sorting = {
        priority_weight = 2.0,
        comparators = {
          compare.offset,
          compare.exact,
          compare.score, -- based on :  score = score + ((#sources - (source_index - 1)) * sorting.priority_weight)
          compare.locality,
          compare.recently_used,
          compare.kind,
          compare.order,
          -- compare.length,
          -- compare.sort_text,
        },
      },
      completion = {
        completeopt = "menu,menuone,noinsert",
      },
      snippet = {
        expand = function(args)
          require("luasnip").lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
        ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
        ["<S-CR>"] = cmp.mapping.confirm({
          behavior = cmp.ConfirmBehavior.Replace,
          select = true,
        }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
        ["<C-CR>"] = function(fallback)
          cmp.abort()
          fallback()
        end,
        ["<Tab>"] = vim.schedule_wrap(function(fallback)
          if cmp.visible() and has_words_before() then
            cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
          else
            fallback()
          end
        end),
      }),
    }
  end,
  config = function(_, opts)
    for _, source in ipairs(opts.sources) do
      source.group_index = source.group_index or 1
    end
    require("cmp").setup(opts)
  end,
}

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
  },
  event = "InsertEnter",
  opts = function()
    -- vim.api.nvim_set_hl(0, "CmpGhostText", { link = "Comment", default = true })
    local cmp = require("cmp")
    -- local defaults = require("cmp.config.default")()
    local compare = require("cmp.config.compare")
    return {
      completion = {
        completeopt = "menu,menuone,noinsert",
      },
      window = {
        completion = cmp.config.window.bordered({
          col_offset = -3,
          side_padding = 0,
          winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
        }),
        documentation = cmp.config.window.bordered({
          winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
        }),
      },
      formatting = {
        fields = { "kind", "abbr", "menu" },
        format = function(entry, vim_item)
          local kind = require("lspkind").cmp_format({ mode = "symbol_text", maxwidth = 50 })(entry, vim_item)
          local strings = vim.split(kind.kind, "%s", { trimempty = true })
          kind.kind = " " .. (strings[1] or "") .. " "
          kind.menu = "    (" .. (strings[2] or "") .. ")"
          return kind
        end,
      },
      enabled = function()
        local disabled = false
        disabled = disabled or (vim.api.nvim_buf_get_option(0, "buftype") == "prompt")
        return not disabled
      end,
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
      }),
      sources = cmp.config.sources({
        { name = "nvim_lsp", priority = 20, group = 1 },
        { name = "crates", priority = 20, group = 1 },
        { name = "vimtex", priority = 15, group = 1 },
        { name = "path", priority = 10, group = 1 },
        { name = "buffer", priority = 10, group = 1 },
        { name = "omni", priority = 9 },
        { name = "luasnip", priority = 9, group = 1 },
        { name = "hledger", priority = 6, group = 1 },
        { name = "copilot", priority = 6 },
        -- { name = "codeium", priority = 6 },
      }),
      experimental = {
        ghost_text = {
          hl_group = "CmpGhostText",
        },
      },
      snippet = {
        expand = function(args)
          require("luasnip").lsp_expand(args.body)
        end,
      },
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
    }
  end,
  config = function(_, opts)
    for _, source in ipairs(opts.sources) do
      source.group_index = source.group_index or 1
    end
    require("cmp").setup(opts)
  end,
}

return {
  "hrsh7th/nvim-cmp",
  dependencies = {
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-emoji",
    "zbirenbaum/copilot-cmp",
    "Exafunction/codeium.nvim",
    "hrsh7th/cmp-nvim-lsp",
    "saadparwaiz1/cmp_luasnip",
    "hrsh7th/cmp-omni",
    "Saecki/crates.nvim",
    "onsails/lspkind.nvim",
    "Saecki/crates.nvim",
  },
  event = "InsertEnter",
  keys = {
    {
      "<tab>",
      function()
        return require("luasnip").jumpable(1) and "<Plug>luasnip-jump-next" or "<tab>"
      end,
      expr = true,
      silent = true,
      mode = "i",
    },
    {
      "<tab>",
      function()
        require("luasnip").jump(1)
      end,
      mode = "s",
    },
    {
      "<s-tab>",
      function()
        require("luasnip").jump(-1)
      end,
      mode = { "i", "s" },
    },
  },
  opts = function(_, opts)
    vim.api.nvim_set_hl(0, "CmpGhostText", { link = "Comment", default = true })
    local cmp = require("cmp")

    local has_words_before = function()
      unpack = unpack or table.unpack
      local line, col = unpack(vim.api.nvim_win_get_cursor(0))
      return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
    end

    opts.mapping = cmp.mapping.preset.insert({
      ["<C-b>"] = cmp.mapping.scroll_docs(-4),
      ["<C-f>"] = cmp.mapping.scroll_docs(4),
      -- ["<C-Space>"] = cmp.mapping.complete(),
      ["<CR>"] = LazyVim.cmp.confirm({ select = auto_select }),
      -- ["<C-y>"] = LazyVim.cmp.confirm({ select = true }),
      -- Commented this one out b/c I don't know what it does. C-CR seems to work fine
      -- ["<S-CR>"] = LazyVim.cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
      -- ["<C-CR>"] = function(fallback)
      --   cmp.abort()
      --   fallback()
      -- end,
    })

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
      { name = "crates", priority = 20, group = 1 },
      { name = "vimtex", priority = 15, group = 1 },
      { name = "path", priority = 12, group = 1 },
      { name = "buffer", priority = 12, group = 1 },
      { name = "omni", priority = 9 },
      { name = "luasnip", priority = 9, group = 1 },
      { name = "copilot", priority = 4, group = 1 },
      -- { name = "codeium", priority = 6, group = 2 },
    })

    opts.snippet = {
      expand = function(args)
        require("luasnip").lsp_expand(args.body)
      end,
    }

    opts.auto_brackets = {
      "python",
    }

    return opts
  end,
  main = "lazyvim.util.cmp",
}

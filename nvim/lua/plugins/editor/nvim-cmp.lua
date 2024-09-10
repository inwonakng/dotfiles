return {
  "hrsh7th/nvim-cmp",
  dependencies = {
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-emoji",
    "zbirenbaum/copilot-cmp",
    "hrsh7th/cmp-nvim-lsp",
    "saadparwaiz1/cmp_luasnip",
    "hrsh7th/cmp-omni",
    "Saecki/crates.nvim",
    "onsails/lspkind.nvim",
    "Saecki/crates.nvim",
  },
  event = "InsertEnter",
  opts = function(_, opts)
    -- vim.api.nvim_set_hl(0, "CmpGhostText", { link = "Comment", default = true })
    local cmp = require("cmp")

    local has_words_before = function()
      unpack = unpack or table.unpack
      local line, col = unpack(vim.api.nvim_win_get_cursor(0))
      return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
    end

    opts.mapping = vim.tbl_extend("force", opts.mapping, {
      ["<Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          -- You could replace select_next_item() with confirm({ select = true }) to get VS Code autocompletion behavior
          cmp.select_next_item()
        elseif vim.snippet.active({ direction = 1 }) then
          vim.schedule(function()
            vim.snippet.jump(1)
          end)
        elseif has_words_before() then
          cmp.complete()
        else
          fallback()
        end
      end, { "i", "s" }),
      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif vim.snippet.active({ direction = -1 }) then
          vim.schedule(function()
            vim.snippet.jump(-1)
          end)
        else
          fallback()
        end
      end, { "i", "s" }),
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
      { name = "path", priority = 10, group = 1 },
      { name = "buffer", priority = 10, group = 1 },
      { name = "omni", priority = 9 },
      { name = "luasnip", priority = 9, group = 1 },
      { name = "copilot", priority = 6 },
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

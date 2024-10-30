return {
  "saghen/blink.cmp",
  lazy = false, -- lazy loading handled internally
  -- optional: provides snippets for the snippet source
  dependencies = { "rafamadriz/friendly-snippets", "saghen/blink.compat" },
  -- use a release tag to download pre-built binaries
  version = "v0.*",
  -- OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
  -- build = 'cargo build --release',
  -- If you use nix, you can build from source using latest nightly rust with:
  -- build = 'nix run .#build-plugin',

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    keymap = {
      -- show = "<D-c>",
      -- accept = "<C-CR>",
      ["<S-CR>"] = { "hide" },
      ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<C-CR>"] = { "select_and_accept" },
      ["<C-n>"] = { "select_next", "fallback" },
      ["<C-p>"] = { "select_prev", "fallback" },
      ["<C-b>"] = { "scroll_documentation_up", "fallback" },
      ["<C-f>"] = { "scroll_documentation_down", "fallback" },
      -- select_next = { "<Tab>", "<Down>", "<C-n>" },
      -- select_prev = { "<S-Tab>", "<Up>", "<C-p>" },
      -- select_next = { "<C-n>" },
      -- select_prev = { "<C-p>" },
      -- scroll_documentation_down = "<PageDown>",
      --  = "<PageUp>",
    },
    highlight = {
      -- sets the fallback highlight groups to nvim-cmp's highlight groups
      -- useful for when your theme doesn't support blink.cmp
      -- will be removed in a future release, assuming themes add support
      -- use_nvim_cmp_as_default = true,
    },
    -- set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
    -- adjusts spacing to ensure icons are aligned
    nerd_font_variant = "mono",

    -- experimental auto-brackets support
    -- accept = { auto_brackets = { enabled = true } }

    -- experimental signature help support
    -- trigger = { signature_help = { enabled = true } }
    sources = {
      completion = { "lsp", "path", "snippets", "buffer" },
      providers = {
        lsp = { name = "LSP", module = "blink.cmp.sources.lsp", score_offset = 1 },
        snippets = {
          name = "Snippets",
          module = "blink.cmp.sources.snippets",
          -- keyword_length = 1, -- not supported yet
          opts = {
            friendly_snippets = true,
            search_paths = { vim.fn.stdpath("config") .. "/snippets" },
            global_snippets = { "all" },
            extended_filetypes = {},
            ignored_filetypes = {},
          },
        },
        path = {
          name = "Path",
          module = "blink.cmp.sources.path",
          score_offset = 3,
          opts = { get_cwd = vim.uv.cwd },
        },
        buffer = {
          name = "Buffer",
          module = "blink.cmp.sources.buffer",
          keyword_length = 3,
          score_offset = -1,
          fallback_for = { "Path", "LSP" }, -- PENDING https://github.com/Saghen/blink.cmp/issues/122
        },
      },
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
        draw = function(ctx)
          -- https://github.com/Saghen/blink.cmp/blob/819b978328b244fc124cfcd74661b2a7f4259f4f/lua/blink/cmp/windows/autocomplete.lua#L285-L349
          -- differentiate LSP snippets from user snippets and emmet snippets
          local icon, source = ctx.kind_icon, ctx.item.source
          local client = source == "LSP" and vim.lsp.get_client_by_id(ctx.item.client_id).name
          if source == "Snippets" or (client == "basics_ls" and ctx.kind == "Snippet") then
            icon = "󰩫"
          elseif source == "Buffer" or (client == "basics_ls" and ctx.kind == "Text") then
            icon = "󰦨"
            -- elseif client == "emmet_language_server" then
            --   icon = "󰯸"
          end

          -- FIX highlight for Tokyonight
          -- local iconHl = vim.g.colors_name:find("tokyonight") and "BlinkCmpKind" or "BlinkCmpKind" .. ctx.kind

          return {
            { icon .. ctx.icon_gap, hl_group = "BlinkCmpKind" .. ctx.kind },
            {
              " " .. ctx.item.label .. " ",
              fill = true,
              hl_group = ctx.deprecated and "BlinkCmpLabelDeprecated" or "BlinkCmpLabel",
              max_width = 45,
            },
          }
        end,
        cycle = { from_top = true, from_bottom = true },
      },
    },
    kind_icons = {
      Text = "",
      Method = "󰊕",
      Function = "󰊕",
      Constructor = "",
      Field = "󰇽",
      Variable = "󰂡",
      Class = "⬟",
      Interface = "",
      Module = "",
      Property = "󰜢",
      Unit = "",
      Value = "󰎠",
      Enum = "",
      Keyword = "󰌋",
      Snippet = "󰒕",
      Color = "󰏘",
      Reference = "",
      File = "󰉋",
      Folder = "󰉋",
      EnumMember = "",
      Constant = "󰏿",
      Struct = "",
      Event = "",
      Operator = "󰆕",
      TypeParameter = "󰅲",
    },
  },
}

local lsp = vim.g.lazyvim_python_lsp or "basedpyright"
local ruff = vim.g.lazyvim_python_ruff or "ruff"

return {
  "neovim/nvim-lspconfig",
  dependencies = { "saghen/blink.cmp" },
  -- config = function(_, opts)
  --   vim.notify("Loading LSP config", "info", { title = "CUSTOM" })
  --   local Keys = require("lazyvim.plugins.lsp.keymaps").get()
  --   -- stylua: ignore
  --   vim.list_extend(Keys, {
  --     { "gd", "<cmd>FzfLua lsp_definitions     jump_to_single_result=true ignore_current_line=true<cr>", desc = "Goto Definition", has = "definition" },
  --     { "gr", "<cmd>FzfLua lsp_references      jump_to_single_result=true ignore_current_line=true<cr>", desc = "References", nowait = true },
  --     { "gI", "<cmd>FzfLua lsp_implementations jump_to_single_result=true ignore_current_line=true<cr>", desc = "Goto Implementation" },
  --     { "gy", "<cmd>FzfLua lsp_typedefs        jump_to_single_result=true ignore_current_line=true<cr>", desc = "Goto T[y]pe Definition" },
  --   })
  --   vim.notify("diag.. " .. tostring(opts.diagnostics.virtual_text), "info", { title = "CUSTOM" })
  -- end,
  opts = {
    setup = {
      [ruff] = function()
        LazyVim.lsp.on_attach(function(client, _)
          -- Disable hover in favor of Pyright
          client.server_capabilities.hoverProvider = false
        end, ruff)
      end,
    },
    codelens = {
      enabled = false,
    },
    diagnostics = {
      underline = true,
      signs = true,
      virtual_text = false,
      float = {
        show_header = true,
        source = "always",
        border = "rounded",
        focusable = true,
      },
      update_in_insert = false, -- default to false
      severity_sort = false, -- default to false
    },
    inlay_hints = {
      enabled = false,
    },
    servers = {
      texlab = {
        keys = {
          { "<Leader>K", "<Plug>(vimtex-doc-package)", desc = "Vimtex Docs", silent = true },
        },
      },
      ruff = {
        cmd_env = { RUFF_TRACE = "messages" },
        init_options = {
          settings = {
            logLevel = "error",
          },
        },
        keys = {
          {
            "<leader>co",
            LazyVim.lsp.action["source.organizeImports"],
            desc = "Organize Imports",
          },
        },
      },
      basedpyright = {
        settings = {
          pyright = {
            -- Using Ruff's import organizer
            disableOrganizeImports = true,
          },
          basedpyright = {
            analysis = {
              -- possible values: off, basic, standard
              typeCheckingMode = "off",
            },
          },
        },
      },
      taplo = {
        keys = {
          {
            "K",
            function()
              if vim.fn.expand("%:t") == "Cargo.toml" and require("crates").popup_available() then
                require("crates").show_popup()
              else
                vim.lsp.buf.hover()
              end
            end,
            desc = "Show Crate Documentation",
          },
        },
      },
      marksman = {},
    },
  },
}

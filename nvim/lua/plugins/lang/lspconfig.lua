local fzf_winopts = require("utils.fzf_winopts")

return {
  "neovim/nvim-lspconfig",
  init = function()
    -- turn off format on save
    vim.g.autoformat = false

    -- override lsp keymaps
    local keys = require("lazyvim.plugins.lsp.keymaps").get()
    vim.list_extend(keys, {
      {
        "gr",
        function()
          require("fzf-lua").lsp_references({ jump_to_single_result = true, winopts = fzf_winopts.large.vertical })
        end,
        desc = "View References",
      },
      {
        "gd",
        function()
          require("fzf-lua").lsp_definitions({ jump_to_single_result = true, winopts = fzf_winopts.large.vertical })
        end,
        desc = "View Definitions",
      },
      {
        "gD",
        function()
          require("fzf-lua").lsp_declarations({ jump_to_single_result = true, winopts = fzf_winopts.large.vertical })
        end,
        desc = "View Declarations",
      },
      {
        "gi",
        function()
          require("fzf-lua").lsp_implementations({ jump_to_single_result = true, winopts = fzf_winopts.large.vertical })
        end,
        desc = "View Implementations",
      },
      {
        "gy",
        function()
          require("fzf-lua").lsp_typedefs({ jump_to_single_result = true, winopts = fzf_winopts.large.vertical })
        end,
        desc = "View Type Definitions",
      },
      -- unbind for comment
      { "<leader>cc", false },
      { "<leader>cl", vim.lsp.codelens.run, desc = "Run Codelens", mode = { "n", "v" }, has = "codeLens" },
    })
  end,
  ---@class PluginLspOpts
  opts = {
    ---@type lspconfig.options
    servers = {
      -- pyright will be automatically installed with mason and loaded with lspconfig
      pyright = {
        settings = {
          python = {
            analysis = {
              useLibraryCodeForTypes = true,
              typeCheckingMode = "off",
              diagnosticMode = "off",
              diagnosticSeverityOverrides = {
                reportUnusedVariable = "warning", -- or anything
              },
            },
          },
        },
      },
      -- tsserver will be automatically installed with mason and loaded with lspconfig
      ---@type lspconfig.options.tsserver
      tsserver = {
        keys = {
          {
            "<leader>co",
            function()
              vim.lsp.buf.code_action({
                apply = true,
                context = {
                  only = { "source.organizeImports.ts" },
                  diagnostics = {},
                },
              })
            end,
            desc = "Organize Imports",
          },
          {
            "<leader>cR",
            function()
              vim.lsp.buf.code_action({
                apply = true,
                context = {
                  only = { "source.removeUnused.ts" },
                  diagnostics = {},
                },
              })
            end,
            desc = "Remove Unused Imports",
          },
        },
        settings = {
          typescript = {
            format = {
              indentSize = vim.o.shiftwidth,
              convertTabsToSpaces = vim.o.expandtab,
              tabSize = vim.o.tabstop,
            },
          },
          javascript = {
            format = {
              indentSize = vim.o.shiftwidth,
              convertTabsToSpaces = vim.o.expandtab,
              tabSize = vim.o.tabstop,
            },
          },
          completions = {
            completeFunctionCalls = true,
          },
        },
      },
      jsonls = {
        -- lazy-load schemastore when needed
        on_new_config = function(new_config)
          new_config.settings.json.schemas = new_config.settings.json.schemas or {}
          vim.list_extend(new_config.settings.json.schemas, require("schemastore").json.schemas())
        end,
        settings = {
          json = {
            format = {
              enable = true,
            },
            validate = { enable = true },
          },
        },
      },
      rust_analyzer = {},
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
    },
    setup = {
      rust_analyzer = function()
        return true
      end,
    },
    diagnostics = {
      underline = true,
      virtual_text = false,
      virtual_lines = {
        only_current_line = true,
        highlight_whole_line = false,
      },
    },
    -- autoformat = false,
    severity_sort = true,
  },
}

return {
  -- add pyright to lspconfig
  "neovim/nvim-lspconfig",
  ---@class PluginLspOpts
  -- dependencies = {
  --   "jose-elias-alvarez/typescript.nvim",
  --   init = function()
  --     require("lazyvim.util").lsp.on_attach(function(client, buffer)
  --       -- stylua: ignore
  --       vim.keymap.set( "n", "<leader>co", "TypescriptOrganizeImports", { buffer = buffer, desc = "Organize Imports" })
  --       vim.keymap.set("n", "<leader>cR", "TypescriptRenameFile", { desc = "Rename File", buffer = buffer })
  --       client.server_capabilities.semanticTokensProvider = nil
  --     end)
  --   end,
  -- },
  ---@class PluginLspOpts
  opts = {
    ---@type lspconfig.options
    servers = {
      -- pyright will be automatically installed with mason and loaded with lspconfig
      pyright = {},
      -- tsserver will be automatically installed with mason and loaded with lspconfig
      tsserver = {},
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
      -- texlab = {
      --   keys = {
      --     { "<Leader>K", "<plug>(vimtex-doc-package)", desc = "Vimtex Docs", silent = true },
      --   },
      -- },
    },
    setup = {
      -- example to setup with typescript.nvim
      tsserver = function(_, opts)
        require("typescript").setup({ server = opts })
        return true
      end,
      -- Specify * to use this function as a fallback for any server
      -- ["*"] = function(server, opts) end,
    },
    autoformat = false,
  },
}

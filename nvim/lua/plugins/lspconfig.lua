local lsp = vim.g.lazyvim_python_lsp or "basedpyright"
local ruff = vim.g.lazyvim_python_ruff or "ruff"

return {
  "neovim/nvim-lspconfig",
  opts = {
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
  },
}

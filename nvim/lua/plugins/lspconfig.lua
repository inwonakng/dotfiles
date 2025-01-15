return {
  "neovim/nvim-lspconfig",
  opts = {
    codelens = {
      enabled = false,
    },
    diagnostics = {
      underline = false,
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

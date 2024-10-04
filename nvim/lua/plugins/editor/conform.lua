return {
  "stevearc/conform.nvim",
  optional = true,
  opts = {
    default_format_opts = {
      timeout_ms = 3000,
      async = false, -- not recommended to change
      quiet = false, -- not recommended to change
    },
    formatters_by_ft = {
      python = { "black" },
      sh = { "shfmt" },
      tex = { "latexindent" },
      html = { "prettier" },
      css = { "prettier" },
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      typescript = { "prettier" },
      typescriptreact = { "prettier" },
      json = { "prettier" },
      jsonc = { "prettier" },
      yaml = { "prettier" },
      markdown = { "prettier" },
      markdowndx = { "prettier" },
      ledger = { "ledger_formatter" },
      lua = { "stylua" },
    },
    formatters = {
      ledger_formatter = {
        command = "ledger_formatter",
      },
    },
  },
}

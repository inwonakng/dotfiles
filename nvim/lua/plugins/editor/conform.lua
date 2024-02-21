return {
  "stevearc/conform.nvim",
  optional = true,
  opts = {
    format = {
      timeout_ms = 3000,
      async = false, -- not recommended to change
      quiet = false, -- not recommended to change
    },
    formatters_by_ft = {
      ["python"] = { "black" },
      ["sh"] = { "shfmt" },
      ["tex"] = { "latexindent" },
      ["html"] = { "prettier" },
      ["css"] = { "prettier" },
      ["javascript"] = { "prettier" },
      ["javascriptreact"] = { "prettier" },
      ["typescript"] = { "prettier" },
      ["typescriptreact"] = { "prettier" },
      ["json"] = { "prettier" },
      ["jsonc"] = { "prettier" },
      ["yaml"] = { "prettier" },
      ["markdown"] = { "prettier" },
      ["markdown.mdx"] = { "prettier" },
      ["ledger"] = { "ledger-formatter" },
    },
    formatters = {
      ledger_formatter = {
        command = "ledger-formatter",

      },
    }
  },
}

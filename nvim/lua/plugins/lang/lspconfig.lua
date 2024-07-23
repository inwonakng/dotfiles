return {
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    local servers = { "pyright", "basedpyright", "ruff", "ruff_lsp", ruff, lsp }
    for _, server in ipairs(servers) do
      opts.servers[server] = opts.servers[server] or {}
      opts.servers[server].enabled = server == lsp or server == ruff
    end
    opts["diagnostics"] = {
      underline = true,
      virtual_text = false,
      virtual_lines = {
        only_current_line = true,
        highlight_whole_line = false,
      },
    }
    -- autoformat = false,
    opts["severity_sort"] = true
  end,
}

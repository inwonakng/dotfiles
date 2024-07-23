return {
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    opts["inlay_hints"] = { enabled = false }
    opts["severity_sort"] = true
    opts.servers["basedpyright"] = {
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
    }

    local Keys = require("lazyvim.plugins.lsp.keymaps").get()
    -- stylua: ignore
    vim.list_extend(Keys, {
      { "gd", "<cmd>FzfLua lsp_definitions     jump_to_single_result=true ignore_current_line=true<cr>", desc = "Goto Definition", has = "definition" },
      { "gr", "<cmd>FzfLua lsp_references      jump_to_single_result=true ignore_current_line=true<cr>", desc = "References", nowait = true },
      { "gI", "<cmd>FzfLua lsp_implementations jump_to_single_result=true ignore_current_line=true<cr>", desc = "Goto Implementation" },
      { "gy", "<cmd>FzfLua lsp_typedefs        jump_to_single_result=true ignore_current_line=true<cr>", desc = "Goto T[y]pe Definition" },
    })
  end,
}

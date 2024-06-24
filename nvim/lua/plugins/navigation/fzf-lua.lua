local fzf_winopts = require("utils.fzf_winopts")

return {
  "ibhagwan/fzf-lua",
  -- optional for icon support
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    {
      "neovim/nvim-lspconfig",
      ---@class PluginLspOpts
      opts = function()
        -- override lsp keymaps
        local keys = require("lazyvim.plugins.lsp.keymaps").get()
        vim.list_extend(keys, {
          {
            "gr",
            function()
              require("fzf-lua").lsp_references({ jump_to_single_result = true, winopts = fzf_winopts.large.vertical })
            end,
            desc = "Go to References",
          },
          {
            "gd",
            function()
              require("fzf-lua").lsp_definitions({ jump_to_single_result = true, winopts = fzf_winopts.large.vertical })
            end,
            desc = "Go to Definitions",
          },
          {
            "gD",
            function()
              require("fzf-lua").lsp_declarations({ jump_to_single_result = true, winopts = fzf_winopts.large.vertical })
            end,
            desc = "Go to Declarations",
          },
          {
            "gi",
            function()
              require("fzf-lua").lsp_implementations({
                jump_to_single_result = true,
                winopts = fzf_winopts.large.vertical,
              })
            end,
            desc = "Go to Implementations",
          },
          {
            "gy",
            function()
              require("fzf-lua").lsp_typedefs({ jump_to_single_result = true, winopts = fzf_winopts.large.vertical })
            end,
            desc = "Go to Type Definitions",
          },
          -- unbind for comment
          { "<leader>cc", false },
          { "<leader>cl", vim.lsp.codelens.run, desc = "Run Codelens", mode = { "n", "v" }, has = "codeLens" },
          -- { "<leader>cc", function() print("U typed cc!") end, desc = "test override", mode = { "n", "v" } },
        })
      end,
    },
  },
  config = function()
    -- calling `setup` is optional for customization
    require("fzf-lua").setup({
      keymap = {
        -- These override the default tables completely
        -- no need to set to `false` to disable a bind
        -- delete or modify is sufficient
        builtin = {
          -- neovim `:tmap` mappings for the fzf win
          ["<F1>"] = "toggle-help",
          ["<F2>"] = "toggle-fullscreen",
          -- Only valid with the 'builtin' previewer
          ["<F3>"] = "toggle-preview-wrap",
          ["<F4>"] = "toggle-preview",
          -- Rotate preview clockwise/counter-clockwise
          ["<F5>"] = "toggle-preview-ccw",
          ["<F6>"] = "toggle-preview-cw",
          ["}"] = "preview-page-down",
          ["{"] = "preview-page-up",
          ["<S-left>"] = "preview-page-reset",
        },
        fzf = {
          -- fzf '--bind=' options
          -- ["ctrl-z"]      = "abort",
          -- ["ctrl-u"]      = "unix-line-discard",
          ["ctrl-d"] = "half-page-down",
          ["ctrl-u"] = "half-page-up",
          ["ctrl-a"] = "beginning-of-line",
          ["ctrl-e"] = "end-of-line",
          ["alt-a"] = "toggle-all",
          -- Only valid with fzf previewers (bat/cat/git/etc)
          ["f3"] = "toggle-preview-wrap",
          ["f4"] = "toggle-preview",
          ["}"] = "preview-page-down",
          ["{"] = "preview-page-up",
        },
      },
    })
  end,
  keys = {
    {
      "<leader>r",
      function()
        require("fzf-lua").resume()
      end,
      desc = "Resume previous search",
    },
    {
      "<leader><space>",
      function()
        local opts = {}
        opts.winopts = fzf_winopts.large.vertical
        require("fzf-lua").live_grep(opts)
      end,
      desc = "Search File Contents",
    },
    {
      "<leader>ff",
      function()
        require("fzf-lua").files({
          winopts = fzf_winopts.large.vertical,
          formatter = "path.filename_first",
        })
      end,
      desc = "Search Files",
    },
    {
      "<C-s>",
      function()
        require("fzf-lua").buffers()
      end,
      desc = "Search Buffers",
    },
    {
      "<leader>ss",
      function()
        require("fzf-lua").builtin()
      end,
      desc = "fzf-lua Built-in Commands",
    },
    {
      "<leader>sm",
      function()
        require("fzf-lua").tmux_buffers()
      end,
      desc = "List Tmux Paste Buffers",
    },
    {
      "<leader>sl",
      function()
        require("fzf-lua").lsp_finder({ winopts = fzf_winopts.large.vertical })
      end,
      desc = "View LSP finder",
    },
    {
      "<leader>dd",
      function()
        require("fzf-lua").dap_commands()
      end,
      desc = "Debugger Commands",
    },
  },
}

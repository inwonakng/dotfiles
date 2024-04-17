local fzf_winopts = require("utils.fzf_winopts")

local get_fzf_opts = function()
  local cmd = nil
  local fzf_opts = nil
  if vim.fn.executable("fd") == 1 then
    local fzfutils = require("fzf-lua.utils")
    -- fzf-lua.defaults#defaults.files.fd_opts
    cmd = string.format(
      [[fd --color=never --type f --hidden --follow --exclude .git -x printf "{}: {/} %s\n"]],
      -- [[fd --color=never --type f --follow --exclude .git -x echo {} | awk -F/ '{printf "%%s: ", $0; printf "%%s ", $NF; gsub(/^\.\//,"",$0); gsub($NF,"",$0); printf "%s ", $0; print ""}']],
      fzfutils.ansi_codes.grey("{//}")
    )
    fzf_opts = {
      -- process ansi colors
      ["--ansi"] = "",
      ["--with-nth"] = "2..",
      ["--delimiter"] = "\\s",
      ["--tiebreak"] = "begin,index",
    }
    -- opts._fmt = opts._fmt or {}
    -- opts._fmt.from = function(entry, _opts)
    --   local s = fzfutils.strsplit(entry, ' ')
    --   return s[3]
    -- end
  end
  return {
    cmd = cmd,
    fzf_opts = fzf_opts,
  }
end

return {
  "ibhagwan/fzf-lua",
  -- optional for icon support
  dependencies = {
    "nvim-tree/nvim-web-devicons",
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
        local opts = get_fzf_opts()
        opts.winopts = fzf_winopts.large.vertical
        require("fzf-lua").files(opts)
      end,
      desc = "Search Files",
    },
    {
      "<leader>sb",
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

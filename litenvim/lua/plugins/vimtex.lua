return {
  "lervag/vimtex",
  lazy = false, -- lazy-loading will disable inverse search
  config = function()
    vim.g.vimtex_view_method = "skim"
    vim.g.vimtex_compiler_latexmk = {
      aux_dir = "./.latexmk/aux",
      out_dir = "./.latexmk/out",
    }
    -- only open quickfix when there are *errors*
    vim.g.vimtex_quickfix_open_on_warning = 0
    vim.g.vimtex_view_skim_sync = 1
  end,
  keys = {
    { "<localLeader>l", "", desc = "+vimtex" },
  },
}

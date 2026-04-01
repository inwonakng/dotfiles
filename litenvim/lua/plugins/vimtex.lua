vim.pack.add({ "https://github.com/lervag/vimtex" })

vim.g.vimtex_view_method = "skim"
vim.g.vimtex_compiler_latexmk = {
	aux_dir = "./.latexmk/aux",
	out_dir = "./.latexmk/out",
}
-- only open quickfix when there are *errors*
vim.g.vimtex_quickfix_open_on_warning = 0
vim.g.vimtex_view_skim_sync = 1

vim.keymap.set("n", "<localLeader>l", "", { desc = "+vimtex" })

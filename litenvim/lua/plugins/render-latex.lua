vim.pack.add({ "https://github.com/techwizrd/render-latex.nvim" })
require("render_latex").setup({
	render = {
		preset = "match_text",
		match_text_size = false,
		font_size = 17,

		-- 4x your baseline scale = 1.25
		scale = 5.0,

		-- 4x default-ish padding
		padding = 40,

		background = "transparent",
	},
	image = {
		backend = "kitty",

		-- 4x your baseline cell estimate
		cell_width_px = 40,
		cell_height_px = 90,
	},

	tmux = {
		install_cleanup_hooks = true,
	},
})

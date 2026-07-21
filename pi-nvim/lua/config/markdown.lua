require("render_latex").setup({
	render = {
		preset = "match_text",
		match_text_size = false,
		font_size = 17,
		scale = 5.0,
		padding = 40,
		background = "transparent",
	},
	image = {
		backend = "kitty",
		cell_width_px = 40,
		cell_height_px = 90,
	},
})

require("render-markdown").setup({
	debounce = 0,
	ignore = function(buf)
		return vim.api.nvim_buf_get_name(buf):match("pi://input$") ~= nil
	end,
	overrides = {
		buftype = {
			nofile = {
				render_modes = true,
			},
		},
	},
	heading = {
		sign = false,
		setext = false,
		custom = {
			pi_user_you = {
				pattern = "You%s*$",
				icon = "󰭹 ",
				background = "PiUserHeader",
				foreground = "PiUserHeader",
			},
			pi_user_user = {
				pattern = "User%s*$",
				icon = "󰭹 ",
				background = "PiUserHeader",
				foreground = "PiUserHeader",
			},
			pi_assistant = {
				pattern = "Assistant%s*$",
				icon = "󰚩 ",
				background = "PiAssistantHeader",
				foreground = "PiAssistantHeader",
			},
		},
	},
	latex = { enabled = false },
})

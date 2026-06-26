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
	callout = {
		pi_tool = {
			raw = "[!PI_TOOL]",
			rendered = "󰇥 Tool",
			highlight = "PiToolQuote",
			category = "pi",
		},
		pi_thinking = {
			raw = "[!PI_THINKING]",
			rendered = "󰔛 Thinking",
			highlight = "PiThinkingQuote",
			category = "pi",
		},
	},
	latex = { enabled = true },
})

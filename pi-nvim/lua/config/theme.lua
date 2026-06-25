local M = {}

M.ui_bg = "#080808"
M.pane_border = "#2a2a2a"

require("catppuccin").setup({
	flavour = "frappe",
	color_overrides = {
		frappe = {
			base = M.ui_bg,
			mantle = M.ui_bg,
			crust = M.ui_bg,
		},
	},
	custom_highlights = function(colors)
		return {
			Normal = { bg = M.ui_bg },
			NormalNC = { bg = M.ui_bg },
			SignColumn = { bg = M.ui_bg },
			EndOfBuffer = { bg = M.ui_bg },
			PiPaneBorder = { fg = M.pane_border, bg = M.ui_bg },
			PiUsageStats = { fg = colors.subtext1, bg = M.ui_bg },
			PiUserHeader = { fg = colors.blue, bg = "#102033", bold = true },
			PiAssistantHeader = { fg = colors.mauve, bg = "#1b1424", bold = true },
			PiModeReadonly = { fg = colors.blue, bg = M.ui_bg, bold = true },
			PiModeWrite = { fg = colors.peach, bg = M.ui_bg, bold = true },
			PiModeUnknown = { fg = colors.subtext1, bg = M.ui_bg, bold = true },
			PiNotifyOn = { fg = colors.green, bg = M.ui_bg, bold = true },
			PiNotifyOff = { fg = colors.overlay0, bg = M.ui_bg },
			PiThinkingOff = { fg = colors.overlay0, bg = M.ui_bg },
			PiThinkingMinimal = { fg = colors.sky, bg = M.ui_bg, bold = true },
			PiThinkingLow = { fg = colors.green, bg = M.ui_bg, bold = true },
			PiThinkingMedium = { fg = colors.yellow, bg = M.ui_bg, bold = true },
			PiThinkingHigh = { fg = colors.peach, bg = M.ui_bg, bold = true },
			PiThinkingXhigh = { fg = colors.red, bg = M.ui_bg, bold = true },
			StatusLine = { fg = M.pane_border, bg = M.ui_bg },
			StatusLineNC = { fg = M.pane_border, bg = M.ui_bg },
			WinBar = { bg = M.ui_bg },
			WinBarNC = { bg = M.ui_bg },
			WinSeparator = { fg = M.pane_border, bg = M.ui_bg },
			DiffAdd = { fg = colors.green, bg = "#102418" },
			DiffChange = { fg = colors.yellow, bg = "#24210f" },
			DiffDelete = { fg = colors.red, bg = "#2a1014" },
			DiffText = { fg = colors.text, bg = "#3a3214", bold = true },
		}
	end,
})
vim.cmd.colorscheme("catppuccin")

return M

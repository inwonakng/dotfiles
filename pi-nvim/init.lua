vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.laststatus = 2
vim.opt.showmode = false
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.termguicolors = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.hidden = true
vim.schedule(function()
	vim.opt.clipboard = "unnamedplus"
end)

local uv = vim.uv or vim.loop
local config_root = uv.fs_realpath(vim.fn.stdpath("config")) or vim.fn.stdpath("config")
local dotfiles_root = vim.fn.fnamemodify(config_root, ":h")
local ui_bg = "#080808"
local pane_border = "#2a2a2a"

vim.pack.add({
	{ src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
	"https://github.com/ibhagwan/fzf-lua",
	"https://github.com/MeanderingProgrammer/render-markdown.nvim",
})

require("catppuccin").setup({
	flavour = "frappe",
	color_overrides = {
		frappe = {
			base = ui_bg,
			mantle = ui_bg,
			crust = ui_bg,
		},
	},
	custom_highlights = function(colors)
		return {
			Normal = { bg = ui_bg },
			NormalNC = { bg = ui_bg },
			SignColumn = { bg = ui_bg },
			EndOfBuffer = { bg = ui_bg },
			PiPaneBorder = { fg = pane_border, bg = ui_bg },
			StatusLine = { fg = pane_border, bg = ui_bg },
			StatusLineNC = { fg = pane_border, bg = ui_bg },
			WinBar = { bg = ui_bg },
			WinBarNC = { bg = ui_bg },
			WinSeparator = { fg = pane_border, bg = ui_bg },
			DiffAdd = { fg = colors.green, bg = "#102418" },
			DiffChange = { fg = colors.yellow, bg = "#24210f" },
			DiffDelete = { fg = colors.red, bg = "#2a1014" },
			DiffText = { fg = colors.text, bg = "#3a3214", bold = true },
		}
	end,
})
vim.cmd.colorscheme("catppuccin")

local fzf_opts = {
	default = {
		["--no-scrollbar"] = true,
		["--pointer"] = "> ",
	},
}
local fzf_winopts = {
	default = {
		border = { "", "-", "", "", "", "", "", "" },
		height = 1.0,
		width = 1.0,
		row = 1.0,
		col = 0,
		preview = {
			layout = "vertical",
			vertical = "up:60%",
			border = "none",
		},
	},
}

local ok, fzf = pcall(require, "fzf-lua")
if ok then
	fzf.register_ui_select(function(select_opts)
		local winopts = vim.deepcopy(fzf_winopts.default)
		if select_opts.kind == "pi_approval" then
			winopts.height = 0.85
			winopts.preview = {
				layout = "vertical",
				vertical = "up:78%",
				border = "none",
			}
		else
			winopts.height = 0.4
		end
		winopts.title = " " .. vim.trim((select_opts.prompt or "Select"):gsub("%s*:%s*$", "")) .. " "
		winopts.title_pos = "left"
		return {
			winopts = winopts,
			fzf_opts = fzf_opts.default,
		}
	end)

	fzf.setup({
		fzf_colors = true,
		fzf_opts = fzf_opts.default,
		winopts = fzf_winopts.default,
	})
else
	vim.notify("fzf-lua unavailable; using native vim.ui.select", vim.log.levels.WARN)
end

require("render-markdown").setup({
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
	},
	latex = { enabled = true },
})

require("pi-integration").setup({
	binary = vim.env.PI_BINARY or "pi",
	agent_dir = vim.env.PI_CODING_AGENT_DIR or (dotfiles_root .. "/pi/agent"),
	provider = vim.env.PI_PROVIDER,
	model = vim.env.PI_MODEL,
	session_dir = vim.env.PI_SESSION_DIR,
	show_thinking = false,
})
require("config.keymaps")
require("config.commands")

-- startup commands
vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		require("pi-integration").open()
	end,
})

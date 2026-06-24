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

vim.api.nvim_create_autocmd({ "BufWinEnter", "VimResized", "WinResized" }, {
	callback = function()
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.api.nvim_buf_get_name(buf):match("pi://input$") then
				vim.api.nvim_set_option_value("wrap", true, { win = win })
				vim.api.nvim_set_option_value("linebreak", true, { win = win })
				vim.api.nvim_set_option_value("breakindent", true, { win = win })
			end
		end
	end,
})

local uv = vim.uv or vim.loop
local config_root = uv.fs_realpath(vim.fn.stdpath("config")) or vim.fn.stdpath("config")
local dotfiles_root = vim.fn.fnamemodify(config_root, ":h")
local ui_bg = "#080808"
local pane_border = "#2a2a2a"

vim.api.nvim_create_autocmd("PackChanged", {
	callback = function(ev)
		local name, kind = ev.data.spec.name, ev.data.kind
		if name == "blink.cmp" and (kind == "install" or kind == "update") then
			if not ev.data.active then
				vim.cmd.packadd(name)
			end
			require("blink.cmp.fuzzy.build").build()
		end
	end,
})

vim.pack.add({
	{ src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
	"https://github.com/ibhagwan/fzf-lua",
	"https://github.com/MeanderingProgrammer/render-markdown.nvim",
	"https://github.com/nvim-treesitter/nvim-treesitter",
	"https://github.com/folke/which-key.nvim",
	"https://github.com/saghen/blink.cmp",
})

vim.api.nvim_create_user_command("BlinkBuild", function()
	require("blink.cmp.fuzzy.build").build()
end, { desc = "Build blink.cmp Rust fuzzy library" })

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
			PiUsageStats = { fg = colors.subtext1, bg = ui_bg },
			PiUserHeader = { fg = colors.blue, bg = "#102033", bold = true },
			PiAssistantHeader = { fg = colors.mauve, bg = "#1b1424", bold = true },
			PiModeReadonly = { fg = colors.blue, bg = ui_bg, bold = true },
			PiModeWrite = { fg = colors.peach, bg = ui_bg, bold = true },
			PiModeUnknown = { fg = colors.subtext1, bg = ui_bg, bold = true },
			PiNotifyOn = { fg = colors.green, bg = ui_bg, bold = true },
			PiNotifyOff = { fg = colors.overlay0, bg = ui_bg },
			PiThinkingOff = { fg = colors.overlay0, bg = ui_bg },
			PiThinkingMinimal = { fg = colors.sky, bg = ui_bg, bold = true },
			PiThinkingLow = { fg = colors.green, bg = ui_bg, bold = true },
			PiThinkingMedium = { fg = colors.yellow, bg = ui_bg, bold = true },
			PiThinkingHigh = { fg = colors.peach, bg = ui_bg, bold = true },
			PiThinkingXhigh = { fg = colors.red, bg = ui_bg, bold = true },
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

local ok_which_key, which_key = pcall(require, "which-key")
if ok_which_key then
	which_key.setup({})
	which_key.add({
		{ "<leader><tab>", group = "tabs" },
		{ "<leader>b", group = "buffers" },
		{ "<leader>i", group = "insert" },
		{ "<leader>u", group = "ui" },
		{ "<leader>w", group = "windows" },
		{ "<leader>y", group = "yank" },
	})
else
	vim.notify("which-key unavailable", vim.log.levels.WARN)
end

local fzf_opts = {
	default = {
		["--no-scrollbar"] = true,
		["--pointer"] = "> ",
	},
}
local fzf_keymap = {
	builtin = {
		["<C-d>"] = "preview-half-page-down",
		["<C-u>"] = "preview-half-page-up",
	},
	fzf = {
		["ctrl-d"] = "preview-half-page-down",
		["ctrl-u"] = "preview-half-page-up",
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

local ok_treesitter, treesitter = pcall(require, "nvim-treesitter.config")
if ok_treesitter then
	treesitter.setup({
		ensure_installed = {
			"markdown",
			"markdown_inline",
			"yaml",
		},
		highlight = {
			enable = true,
		},
	})
else
	vim.notify("nvim-treesitter unavailable; markdown injections may be missing", vim.log.levels.WARN)
end

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
				wrap = true,
			}
		else
			winopts.height = 0.4
		end
		winopts.title = " " .. vim.trim((select_opts.prompt or "Select"):gsub("%s*:%s*$", "")) .. " "
		winopts.title_pos = "left"
		return {
			winopts = winopts,
			fzf_opts = fzf_opts.default,
			keymap = fzf_keymap,
		}
	end)

	fzf.setup({
		fzf_colors = true,
		fzf_opts = fzf_opts.default,
		keymap = fzf_keymap,
		winopts = fzf_winopts.default,
	})
else
	vim.notify("fzf-lua unavailable; using native vim.ui.select", vim.log.levels.WARN)
end

local ok_blink, blink = pcall(require, "blink.cmp")
if ok_blink then
	blink.setup({
		cmdline = {
			enabled = false,
		},
		keymap = {
			["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
			["<C-e>"] = { "hide", "fallback" },
			["<CR>"] = { "accept", "fallback" },
			["<Tab>"] = { "snippet_forward", "fallback" },
			["<S-Tab>"] = { "snippet_backward", "fallback" },
			["<Up>"] = { "select_prev", "fallback" },
			["<Down>"] = { "select_next", "fallback" },
			["<C-p>"] = { "select_prev", "fallback" },
			["<C-n>"] = { "select_next", "fallback" },
			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
			["<C-k>"] = { "show_signature", "hide_signature", "fallback" },
		},
		appearance = {
			use_nvim_cmp_as_default = true,
			nerd_font_variant = "mono",
		},
		completion = {
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 500,
			},
		},
		sources = {
			default = {
				"lsp",
				"path",
				"snippets",
				"buffer",
			},
			providers = {
				path = {
					opts = {
						get_cwd = function(_)
							return vim.fn.getcwd()
						end,
					},
				},
			},
		},
	})
else
	vim.notify("blink.cmp unavailable; completion disabled", vim.log.levels.WARN)
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

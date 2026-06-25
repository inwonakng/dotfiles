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

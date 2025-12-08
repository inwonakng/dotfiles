local M = {}

local api, fn, bo = vim.api, vim.fn, vim.bo
local get_opt = api.nvim_get_option_value

local icons = tools.ui.icons
-- local mini_icons = require("mini.icons")

local HL = {
	branch = { "DiagnosticOk", icons.branch },
	file = { "NonText", icons.node },
	fileinfo = { "Function", icons.document },
	nomodifiable = { "DiagnosticWarn", icons.bullet },
	modified = { "DiagnosticError", icons.bullet },
	readonly = { "DiagnosticWarn", icons.lock },
	error = { "DiagnosticError", icons.error },
	warn = { "DiagnosticWarn", icons.warning },
	visual = { "DiagnosticInfo", "‹› " },
}

local ICON = {}
for k, v in pairs(HL) do
	ICON[k] = tools.hl_str(v[1], v[2])
end

local ORDER = {
	"pad",
	"path",
	"venv",
	"mod",
	"ro",
	"sep",
	"ai_copilot",
	"ai_cli",
	"pad",
	"diag",
	"fileinfo",
	"pad",
	"scrollbar",
	"pad",
}

local SEP = "%="
local SBAR = { "▔", "🮂", "🬂", "🮃", "▀", "▄", "▃", "🬭", "▂", "▁" }

-- utilities -----------------------------------------
local function concat(parts)
	local out, i = {}, 1
	for _, k in ipairs(ORDER) do
		local v = parts[k]
		if v and v ~= "" then
			out[i] = v
			i = i + 1
		end
	end
	return table.concat(out, " ")
end

local function esc_str(str)
	return str:gsub("([%(%)%%%+%-%*%?%[%]%^%$])", "%%%1")
end

-- path and git info -----------------------------------------
local devicons = require("nvim-web-devicons")

local function path_widget(buf_bo, root, fname)
	local file_name = fn.fnamemodify(fname, ":t")

	local path, icon, hl
	-- icon, hl = mini_icons.get("file", file_name)
	icon, hl = devicons.get_icon(fname, nil, { default = true })
	hl = hl or "NonText"
	icon = " " .. (icon or "") .. " "

	if fname == "" then
		file_name = "[No Name]"
	end
	path = tools.hl_str(hl, icon) .. " " .. file_name

	local dir_path = fn.fnamemodify(fname, ":h") .. "/"
	if dir_path == "./" then
		dir_path = ""
	end

	local remote = tools.get_git_remote_name(root)
	local branch = tools.get_git_branch(root)
	local repo_info = ""
	if remote and branch then
		dir_path = dir_path:gsub("^" .. esc_str(root) .. "/", "")
		repo_info = string.format("%s %s @ %s ", ICON.branch, remote, branch)
	end

	local win_w = api.nvim_win_get_width(0)
	local need = #repo_info + #dir_path + #path
	if win_w < need + 5 then
		dir_path = ""
	end
	if win_w < need - #dir_path then
		repo_info = ""
	end
	return path .. " "
end

-- AI stuff (copilot and cli)

local function ai_copilot_info_widget(buf)
	-- show status about AI code assistants like copilot, chatgpt, etc.
	local status = require("sidekick.status").get()
	if status == nil then
		return ""
	else
		local icon = tools.ui.kind_icons.Copilot
		local color = status.kind == "Error" and "DiagnosticError" or status.busy and "DiagnosticWarn" or "Special"
		return tools.hl_str(color, icon)
	end
end

local function ai_cli_info_widget(buf)
	-- show status about AI code assistants like copilot, chatgpt, etc.
	local status = require("sidekick.status").cli()
	local icon = tools.ui.kind_icons.Bot
	local color = status.kind == "Error" and "DiagnosticError" or status.busy and "DiagnosticWarn" or "Special"
	return tools.hl_str(color, icon .. (#status > 1 and #status or ""))
end

-- diagnostics ---------------------------------------------
local function diagnostics_widget(buf)
	if not tools.diagnostics_available(buf) then
		return ""
	end
	local diag_count = vim.diagnostic.count(buf) or {}
	local sev = vim.diagnostic.severity
	local err = string.format("%-3d", diag_count[sev.ERROR] or 0)
	local warn = string.format("%-3d", diag_count[sev.WARN] or 0)

	return string.format(
		"%s%s%s%s",
		ICON.error,
		tools.hl_str("DiagnosticError", err),
		ICON.warn,
		tools.hl_str("DiagnosticWarn", warn)
	)
end

-- file/selection info -------------------------------------
local function fileinfo_widget(buf)
	local ft = get_opt("filetype", { buf = buf })
	local lines = tools.group_number(api.nvim_buf_line_count(buf), ",")
	local str = ICON.fileinfo .. " "

	if not tools.nonprog_modes[ft] then
		return str .. string.format("%3s lines", lines)
	end

	local wc = api.nvim_buf_call(buf, function()
		local data = fn.wordcount()
		if data.visual_words then
			data._visual_lines = math.abs(fn.line(".") - fn.line("v")) + 1
		end
		return data
	end)
	if not wc.visual_words then
		return str .. string.format("%3s lines  %3s words", lines, tools.group_number(wc.words, ","))
	end

	local vlines = wc._visual_lines or 0
	return str
		.. string.format(
			"%3s lines %3s words  %3s chars",
			tools.group_number(vlines, ","),
			tools.group_number(wc.visual_words, ","),
			tools.group_number(wc.visual_chars, ",")
		)
end

function M.render()
	local win = vim.g.statusline_winid or api.nvim_get_current_win()
	local buf = api.nvim_win_get_buf(win)
	local buf_bo = bo[buf]

	-- skip help and nofile buffers
	if buf_bo.buftype == "help" or buf_bo.buftype == "nofile" then
		return ""
	end

	local fname = api.nvim_buf_get_name(buf)
	local root = (buf_bo.buftype == "" and tools.get_path_root(fname)) or nil
	if buf_bo.buftype ~= "" then
		fname = buf_bo.ft
	end

	local parts = {
		-- pad = PAD,
		path = path_widget(buf_bo, root, fname),
		-- venv = venv_widget(buf_bo),
		mod = get_opt("modifiable", { buf = buf }) and (get_opt("modified", { buf = buf }) and ICON.modified or " ")
			or ICON.nomodifiable,
		ro = get_opt("readonly", { buf = buf }) and ICON.readonly or "",
		-- pad = PAD,
		sep = SEP,
		diag = diagnostics_widget(buf),
		-- ai_copilot = ai_copilot_info_widget(buf),
		-- ai_cli = ai_cli_info_widget(buf),
		fileinfo = fileinfo_widget(buf),
		-- scrollbar = scrollbar_widget(win, buf),
	}

	return concat(parts)
end

-- vim.o.statusline = "%!v:lua.require('ui.statusline').render()"

return M

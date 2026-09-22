local M = {}

local api = vim.api
local namespace = api.nvim_create_namespace("fzf_lua_codeaction_inline_diff")
local highlight_augroup = api.nvim_create_augroup("FzfLuaCodeActionHighlights", { clear = true })
local attached_buffers = {}

local function set_highlights()
	api.nvim_set_hl(0, "FzfLuaCodeActionAddText", { default = true, link = "DiffText" })
	api.nvim_set_hl(0, "FzfLuaCodeActionDeleteText", { default = true, link = "DiffText" })
end

api.nvim_create_autocmd("ColorScheme", {
	group = highlight_augroup,
	callback = set_highlights,
})
set_highlights()

local function codepoint_diff_input(text)
	local positions = vim.str_utf_pos(text)
	local codepoints = {}

	for i, start_byte in ipairs(positions) do
		local end_byte = positions[i + 1] or (#text + 1)
		codepoints[i] = text:sub(start_byte, end_byte - 1)
	end

	local input = #codepoints > 0 and (table.concat(codepoints, "\n") .. "\n") or ""
	return input, positions
end

local function byte_offset(text, positions, codepoint_index)
	local position = positions[codepoint_index]
	return position and (position - 1) or #text
end

local function highlight_range(bufnr, row, text, positions, start_index, count, highlight)
	if count == 0 then
		return
	end

	local start_col = 1 + byte_offset(text, positions, start_index)
	local end_col = 1 + byte_offset(text, positions, start_index + count)
	api.nvim_buf_set_extmark(bufnr, namespace, row, start_col, {
		end_row = row,
		end_col = end_col,
		hl_group = highlight,
		hl_mode = "combine",
		priority = 200,
		strict = false,
	})
end

local function highlight_line_pair(bufnr, removed, added)
	local removed_input, removed_positions = codepoint_diff_input(removed.text)
	local added_input, added_positions = codepoint_diff_input(added.text)
	local hunks = vim.text.diff(removed_input, added_input, { result_type = "indices" })

	for _, hunk in ipairs(hunks) do
		highlight_range(
			bufnr,
			removed.row,
			removed.text,
			removed_positions,
			hunk[1],
			hunk[2],
			"FzfLuaCodeActionDeleteText"
		)
		highlight_range(
			bufnr,
			added.row,
			added.text,
			added_positions,
			hunk[3],
			hunk[4],
			"FzfLuaCodeActionAddText"
		)
	end
end

local function highlight_block(bufnr, removed, added)
	if #removed ~= #added then
		return
	end

	for i = 1, #removed do
		highlight_line_pair(bufnr, removed[i], added[i])
	end
end

local function highlight_buffer(bufnr)
	if not api.nvim_buf_is_valid(bufnr) then
		return
	end

	api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local removed = {}
	local added = {}
	local in_hunk = false

	local function flush_block()
		highlight_block(bufnr, removed, added)
		removed = {}
		added = {}
	end

	for index, line in ipairs(lines) do
		if line:match("^@@") then
			flush_block()
			in_hunk = true
		elseif line:match("^diff ") then
			flush_block()
			in_hunk = false
		elseif in_hunk then
			local prefix = line:sub(1, 1)
			if prefix == "-" then
				if #added > 0 then
					flush_block()
				end
				removed[#removed + 1] = { row = index - 1, text = line:sub(2) }
			elseif prefix == "+" then
				added[#added + 1] = { row = index - 1, text = line:sub(2) }
			else
				flush_block()
			end
		end
	end

	flush_block()
end

local function attach_highlighter(bufnr)
	if not api.nvim_buf_is_valid(bufnr) then
		return
	end

	highlight_buffer(bufnr)
	if attached_buffers[bufnr] then
		return
	end

	attached_buffers[bufnr] = true
	local attached = api.nvim_buf_attach(bufnr, false, {
		on_lines = function()
			vim.schedule(function()
				highlight_buffer(bufnr)
			end)
		end,
		on_detach = function()
			attached_buffers[bufnr] = nil
		end,
	})

	if not attached then
		attached_buffers[bufnr] = nil
	end
end

local codeaction_builtin = require("fzf-lua.previewer.codeaction").builtin
local codeaction_previewer = codeaction_builtin:extend()

function codeaction_previewer:new(opts, picker_opts, fzf_win)
	codeaction_previewer.super.new(self, opts, picker_opts, fzf_win)
	setmetatable(self, codeaction_previewer)
end

function codeaction_previewer:gen_winopts()
	local winopts = codeaction_previewer.super.gen_winopts(self)
	winopts.wrap = true
	return winopts
end

function codeaction_previewer:set_preview_buf(bufnr, ...)
	codeaction_previewer.super.set_preview_buf(self, bufnr, ...)
	attach_highlighter(bufnr)
end

function M.previewer()
	local previewer = vim.deepcopy(require("fzf-lua.config").globals.previewers.codeaction)
	previewer._ctor = function()
		return codeaction_previewer
	end
	return previewer
end

return M

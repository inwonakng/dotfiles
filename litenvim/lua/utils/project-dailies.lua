local M = {}
local views = {}
local separators = vim.api.nvim_create_namespace("project-dailies-separators")

vim.api.nvim_set_decoration_provider(separators, {
	on_win = function(_, window, buffer)
		for _, state in pairs(views) do
			if state.buffer == buffer and not state.pending then
				-- Leave a protected blank above and below each full-width rule.
				local count = vim.api.nvim_buf_line_count(buffer)
				for i = 2, #state.sections do
					local row = state.sections[i].first - 3
					if row >= 0 and row < count then
						vim.api.nvim_buf_set_extmark(buffer, separators, row, 0, {
							ephemeral = true,
							virt_text = { { string.rep("━", vim.api.nvim_win_get_width(window)), "NonText" } },
							virt_text_win_col = 0,
						})
					end
				end
				break
			end
		end
		return false
	end,
})

local function read(path)
	local file, err = io.open(path, "rb")
	if not file then
		error("Could not read " .. path .. ": " .. tostring(err))
	end
	local bytes, read_error = file:read("*a")
	file:close()
	if not bytes then
		error("Could not read " .. path .. ": " .. tostring(read_error))
	end
	return bytes
end

local function decode(bytes)
	local newline = bytes:find("\r\n", 1, true) and "\r\n" or "\n"
	-- Keep mixed line endings byte-for-byte rather than normalizing them.
	if newline == "\r\n" and bytes:gsub("\r\n", ""):find("\n", 1, true) then
		newline = "\n"
	end
	local eol = bytes:sub(-#newline) == newline
	local text = eol and bytes:sub(1, -#newline - 1) or bytes
	return vim.split(text, newline, { plain = true }), newline, eol
end

-- Only an initial, closed YAML block is metadata. Keep its original bytes,
-- including delimiter whitespace and line endings, separate from editable text.
local function frontmatter(bytes)
	local first_end = bytes:find("\n", 1, true)
	if not first_end or not bytes:sub(1, first_end - 1):gsub("\r$", ""):match("^%-%-%-[ \t]*$") then
		return "", bytes, 0
	end
	local start, offset = first_end + 1, 1
	while start <= #bytes do
		local ending = bytes:find("\n", start, true)
		local line = bytes:sub(start, ending and ending - 1 or #bytes):gsub("\r$", "")
		offset = offset + 1
		if line:match("^%-%-%-[ \t]*$") or line:match("^%.%.%.[ \t]*$") then
			local last = ending or #bytes
			return bytes:sub(1, last), bytes:sub(last + 1), offset
		end
		if not ending then
			break
		end
		start = ending + 1
	end
	return "", bytes, 0
end

local function encode(state, section)
	local lines = {}
	for row = section.first + 1, section.last do
		lines[#lines + 1] = state.lines[row]
	end
	local body = table.concat(lines, section.newline) .. (section.eol and section.newline or "")
	local prefix = section.frontmatter
	-- A metadata-only note may end at its closing delimiter without a newline.
	if body ~= "" and prefix ~= "" and prefix:sub(-1) ~= "\n" then
		prefix = prefix .. section.newline
	end
	return prefix .. body
end

local function dirty(state)
	for _, section in ipairs(state.sections) do
		if encode(state, section) ~= section.snapshot then
			return true
		end
	end
	return false
end

-- Minimal changed line interval, independent of how broadly an API replaces text.
local function difference(before, after)
	local first = 0
	while first < math.min(#before, #after) and before[first + 1] == after[first + 1] do
		first = first + 1
	end
	local old_last, new_last = #before, #after
	while old_last > first and new_last > first and before[old_last] == after[new_last] do
		old_last, new_last = old_last - 1, new_last - 1
	end
	return first, old_last, new_last
end

local function fingerprint(lines)
	return vim.fn.sha256(table.concat(lines, "\n"))
end

local function remember(state)
	local ranges = {}
	for i, section in ipairs(state.sections) do
		ranges[i] = { section.first, section.last }
	end
	-- Only ranges and a digest are retained, not another copy of every note.
	-- Undo can restore several sections at once, including a rejected edit's rollback.
	state.history[fingerprint(state.lines)] = ranges
end

local function accept(state, lines, first, old_last, new_last)
	if vim.deep_equal(state.lines, lines) then
		return true
	end
	local changed
	if first then
		for i, section in ipairs(state.sections) do
			if first >= section.first and old_last <= section.last then
				changed = i
				break
			end
		end
	end
	if changed then
		local delta = new_last - old_last
		if state.sections[changed].last + delta <= state.sections[changed].first then
			return false -- Keep an editable blank line even for an empty source.
		end
		state.sections[changed].last = state.sections[changed].last + delta
		for i = changed + 1, #state.sections do
			state.sections[i].first = state.sections[i].first + delta
			state.sections[i].last = state.sections[i].last + delta
		end
	else
		local known = state.history[fingerprint(lines)]
		if not known then
			return false
		end
		for i, section in ipairs(state.sections) do
			section.first, section.last = unpack(known[i])
		end
	end
	state.lines = lines
	remember(state)
	return true
end

local function attach_guard(state)
	vim.api.nvim_buf_attach(state.buffer, false, {
		on_lines = function(_, _, _, first, old_last, new_last)
			if state.restoring or state.pending then
				return
			end
			local lines = vim.api.nvim_buf_get_lines(state.buffer, 0, -1, false)
			-- Use edit coordinates, never delimiter searches or a text diff: a note
			-- may itself end with exactly the same blank lines and separators.
			if accept(state, lines, first, old_last, new_last) then
				return
			end
			state.pending = true
			-- Text updates are forbidden under on_lines' textlock. Writes also check
			-- pending synchronously, so rejected text can never reach a source file.
			vim.schedule(function()
				if not state.pending or not vim.api.nvim_buf_is_valid(state.buffer) then
					return
				end
				local current = vim.api.nvim_buf_get_lines(state.buffer, 0, -1, false)
				-- An undo can emit intermediate invalid text before restoring a valid state.
				if not accept(state, current) then
					local first, old_last, new_last = difference(current, state.lines)
					state.restoring = true
					vim.api.nvim_buf_call(state.buffer, function()
						pcall(vim.cmd, "undojoin")
						vim.api.nvim_buf_set_lines(
							state.buffer,
							first,
							old_last,
							false,
							vim.list_slice(state.lines, first + 1, new_last)
						)
					end)
					state.restoring = false
					vim.notify(
						"Project dailies: edit only inside a project's contents (keep a blank line for an empty note)",
						vim.log.levels.WARN
					)
				end
				state.pending = false
				vim.bo[state.buffer].modified = dirty(state)
			end)
		end,
	})
end

local function source_buffers(path)
	local buffers = {}
	for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buffer) and vim.uv.fs_realpath(vim.api.nvim_buf_get_name(buffer)) == path then
			buffers[#buffers + 1] = buffer
		end
	end
	return buffers
end

-- Replace a source only after its complete contents and permissions are ready.
-- A failed write/close/rename leaves the original available for an ordinary retry.
local function replace_source(path, bytes)
	local uv = vim.uv
	local stat, err = uv.fs_stat(path)
	if not stat then
		return nil, err
	end
	local file, temporary = uv.fs_mkstemp(vim.fs.joinpath(vim.fs.dirname(path), ".project-dailies-XXXXXX"))
	if not file then
		return nil, temporary
	end
	local failure
	local offset = 0
	while offset < #bytes do
		local written, write_error = uv.fs_write(file, bytes:sub(offset + 1), offset)
		if not written or written == 0 then
			failure = write_error or "Write made no progress"
			break
		end
		offset = offset + written
	end
	if not failure then
		local changed, mode_error = uv.fs_fchmod(file, stat.mode % 4096)
		if not changed then
			failure = mode_error
		end
	end
	local closed, close_error = uv.fs_close(file)
	if not closed then
		failure = failure or close_error
	end
	if not failure then
		local renamed, rename_error = uv.fs_rename(temporary, path)
		if renamed then
			return true
		end
		failure = rename_error
	end
	local removed, cleanup_error = uv.fs_unlink(temporary)
	if not removed then
		failure = tostring(failure) .. "; could not remove " .. temporary .. ": " .. tostring(cleanup_error)
	end
	return nil, failure
end

local function save(state, event)
	if event.event ~= "BufWriteCmd" or event.match ~= vim.api.nvim_buf_get_name(state.buffer) or vim.v.cmdarg ~= "" then
		error("Project dailies: only :write to this virtual buffer is supported")
	end
	if state.pending or not vim.deep_equal(state.lines, vim.api.nvim_buf_get_lines(state.buffer, 0, -1, false)) then
		error("Project dailies: a protected edit is being reverted; retry :write")
	end
	local changes = {}
	-- Preflight every changed source before writing any of them. Force does not
	-- bypass conflicts, and unmodified sections never touch their source files.
	for _, section in ipairs(state.sections) do
		local bytes = encode(state, section)
		if bytes ~= section.snapshot then
			if read(section.path) ~= section.snapshot then
				error("Project dailies: source changed on disk: " .. section.path)
			end
			local buffers = source_buffers(section.path)
			for _, buffer in ipairs(buffers) do
				if vim.bo[buffer].modified then
					error("Project dailies: source has unsaved buffer edits: " .. section.path)
				end
			end
			changes[#changes + 1] = { section = section, bytes = bytes, buffers = buffers }
		end
	end
	local saved, saved_changes, refresh_errors = {}, {}, {}
	local failure
	for _, change in ipairs(changes) do
		local path = change.section.path
		local written, err = replace_source(path, change.bytes)
		if not written then
			failure = ("Project dailies: write failed for %s: %s; saved: %s; remaining edits are unsaved"):format(
				path,
				tostring(err),
				#saved > 0 and table.concat(saved, ", ") or "none"
			)
			break
		end
		change.section.snapshot = change.bytes
		saved[#saved + 1] = path
		saved_changes[#saved_changes + 1] = change
	end
	-- Reload only after persistence is finished: reload autocommands must not run
	-- between the all-source conflict check and writing the remaining sources.
	for _, change in ipairs(saved_changes) do
		for _, buffer in ipairs(change.buffers) do
			if not vim.bo[buffer].modified then
				local ok, refresh_error = pcall(vim.api.nvim_buf_call, buffer, function()
					vim.cmd("silent keepalt edit!")
				end)
				if not ok then
					refresh_errors[#refresh_errors + 1] = tostring(refresh_error)
				end
			end
		end
	end
	vim.bo[state.buffer].modified = failure ~= nil or dirty(state)
	if #refresh_errors > 0 then
		vim.notify(
			"Sources saved, but could not refresh loaded buffers: " .. table.concat(refresh_errors, "; "),
			vim.log.levels.WARN
		)
	end
	if failure then
		error(failure)
	end
	vim.notify(("Project dailies: saved %d source(s)"):format(#saved))
end

local function jump(state)
	if state.pending then
		return
	end
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	for _, section in ipairs(state.sections) do
		-- The heading also jumps to the start of the note.
		if row >= section.first - 1 and row < section.last then
			local line = section.source_offset + math.max(1, row - section.first + 1)
			vim.cmd("keepalt split " .. vim.fn.fnameescape(section.path))
			vim.api.nvim_win_set_cursor(0, { math.min(line, vim.api.nvim_buf_line_count(0)), 0 })
			return
		end
	end
	vim.notify("Project dailies: no source at this line")
end

local function collect(workspace, date)
	local sections, seen = {}, {}
	local directory = vim.fs.joinpath(workspace.path, "projects")
	local scan, err, code = vim.uv.fs_scandir(directory)
	if not scan and code ~= "ENOENT" then
		error("Could not list " .. directory .. ": " .. tostring(err))
	end
	local projects = {}
	if scan then
		while true do
			local name, kind = vim.uv.fs_scandir_next(scan)
			if not name then
				break
			end
			if kind == "directory" then
				projects[#projects + 1] = name
			end
		end
	end
	table.sort(projects)
	for _, project in ipairs(projects) do
		local path = require("utils.project-notes").ensure_daily(workspace, "projects/" .. project)
		if vim.fs.basename(path) ~= date .. ".md" then
			error("Daily date changed while collecting projects; reopen ProjectDailies")
		end
		path = assert(vim.uv.fs_realpath(path), "Daily is unavailable: " .. path)
		if not seen[path] then
			seen[path] = true
			local bytes = read(path)
			local metadata, body, offset = frontmatter(bytes)
			local lines, newline, eol = decode(body)
			if not body:find("\n", 1, true) then
				local _, source_newline = decode(bytes)
				newline = source_newline
			end
			sections[#sections + 1] = {
				label = project:gsub("[\r\n]", " "),
				path = path,
				snapshot = bytes,
				frontmatter = metadata,
				source_offset = offset,
				contents = lines,
				newline = newline,
				eol = eol,
			}
		end
	end
	return sections
end

local function render(sections, date)
	local lines = { "---", "date: " .. date, "---", "", "# Project dailies - " .. date, "" }
	for i, section in ipairs(sections) do
		lines[#lines + 1] = "## " .. section.label
		section.first = #lines
		vim.list_extend(lines, section.contents)
		section.contents = nil
		section.last = #lines
		if i < #sections then
			vim.list_extend(lines, { "", "", "" })
		end
	end
	return lines
end

local function populate(state)
	-- A reload is a new snapshot: undo must not resurrect old source contents.
	local levels = vim.bo[state.buffer].undolevels
	vim.bo[state.buffer].undolevels = -1
	vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, state.lines)
	vim.bo[state.buffer].undolevels = levels
	state.pending = false
	vim.bo[state.buffer].modified = dirty(state)
	remember(state)
	attach_guard(state)
end

local function reload(state, workspace, date)
	local ok, sections = pcall(collect, workspace, date)
	if ok then
		state.sections = sections
		state.lines = render(sections, date)
		state.history = {}
	end
	-- :edit unloads the text and detaches on_lines before BufReadCmd. Restore
	-- the previous snapshot on failure, and reattach the guard in either case.
	populate(state)
	if not ok then
		error(sections)
	end
end

function M.open(workspace)
	local date = os.date("%Y-%m-%d")
	local root = vim.uv.fs_realpath(workspace.path)
	if not root then
		vim.notify("Vault directory is unavailable: " .. workspace.path, vim.log.levels.ERROR)
		return
	end
	workspace = { name = workspace.name, path = root }
	local key = root .. "\n" .. date
	local existing = views[key]
	if existing and vim.api.nvim_buf_is_valid(existing.buffer) and vim.api.nvim_buf_is_loaded(existing.buffer) then
		local windows = vim.fn.win_findbuf(existing.buffer)
		if windows[1] then
			vim.api.nvim_set_current_win(windows[1])
		else
			vim.cmd("tab sbuffer " .. existing.buffer)
		end
		return existing.buffer
	end
	local ok, result = pcall(function()
		if existing and vim.api.nvim_buf_is_valid(existing.buffer) then
			vim.api.nvim_buf_delete(existing.buffer, { force = true })
		end
		local sections = collect(workspace, date)
		if #sections == 0 then
			vim.notify("No projects found in the current Obsidian vault")
			return
		end
		local lines = render(sections, date)
		local buffer = vim.api.nvim_create_buf(true, false)
		local state = { buffer = buffer, sections = sections, lines = lines, history = {} }
		vim.api.nvim_buf_set_name(buffer, "project-dailies://" .. vim.uri_encode(root, "rfc3986") .. "/" .. date)
		vim.b[buffer].project_dailies_workspace = workspace
		vim.bo[buffer].buftype = "acwrite"
		vim.bo[buffer].bufhidden = "hide"
		vim.bo[buffer].swapfile = false
		populate(state)
		vim.api.nvim_create_autocmd("BufReadCmd", {
			buffer = buffer,
			callback = function()
				reload(state, workspace, date)
			end,
		})
		vim.api.nvim_create_autocmd({ "BufWriteCmd", "FileWriteCmd", "FileAppendCmd" }, {
			buffer = buffer,
			callback = function(event)
				save(state, event)
			end,
		})
		vim.api.nvim_create_autocmd("BufFilePre", {
			buffer = buffer,
			callback = function()
				error("Project dailies: this virtual buffer cannot be renamed or saved elsewhere")
			end,
		})
		vim.keymap.set("n", "gf", function()
			jump(state)
		end, { buffer = buffer, desc = "Jump to project daily source" })
		views[key] = state
		vim.cmd("tab sbuffer " .. buffer)
		vim.bo[buffer].filetype = "markdown"
		return buffer
	end)
	if not ok then
		vim.notify(tostring(result), vim.log.levels.ERROR)
		return
	end
	return result
end

return M

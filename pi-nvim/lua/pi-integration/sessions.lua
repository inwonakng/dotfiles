local guard = require("pi-integration.utils.guard")
local json = require("pi-integration.utils.json")
local message_utils = require("pi-integration.utils.message")

local M = {}

local ARCHIVED_SUFFIX = ".archived"
local ARCHIVE_AFTER_DAYS = 180
local ARCHIVE_REMINDER_DAYS = 30
local DAY_SECONDS = 24 * 60 * 60
local reminder_checked = false

local function dirname(path)
	if not path or path == "" then
		return nil
	end
	return vim.fn.fnamemodify(path, ":h")
end

local function decode_record(line)
	return json.decode_object(line)
end

local function record_message_text(message)
	return message_utils.extract_text(message)
end

local function fallback_title(text)
	text = vim.trim((text or ""):gsub("%s+", " "))
	text = text:gsub("^[Hh]ey[,:%s]+", "")
	text = text:gsub("^[Hh]i[,:%s]+", "")
	text = text:gsub("^[Hh]ello[,:%s]+", "")
	text = text:gsub("[%.%?!:;,]+$", "")
	if #text > 64 then
		text = vim.trim(text:sub(1, 61)) .. "..."
	end
	return text ~= "" and text or nil
end

local function looks_like_bad_model_title(title)
	if type(title) ~= "string" or title == "" then
		return false
	end
	local lower = title:lower()
	return lower:find("<tool_call>", 1, true)
		or lower:find("```", 1, true)
		or lower:match("^sure[%s!,.]")
		or lower:match("^sorry[%s!,.]")
		or lower:match("^i'm sorry")
		or lower:match("^im sorry")
		or lower:match("^i don't")
		or lower:match("^i cannot")
		or lower:match("^i can't")
		or lower:match("^i'll")
		or lower:match("^i will")
		or lower:match("^let me")
end

local function read_candidate(path)
	local candidate = {
		path = path,
		mtime = vim.fn.getftime(path),
		title = nil,
		cwd = nil,
	}
	local first_user_title = nil

	for _, line in ipairs(vim.fn.readfile(path)) do
		local record = decode_record(line)
		if record and record.type == "session" and type(record.cwd) == "string" and record.cwd ~= "" then
			candidate.cwd = record.cwd
		elseif record and record.type == "session_info" and type(record.name) == "string" and vim.trim(record.name) ~= "" then
			candidate.title = vim.trim(record.name)
		elseif record and not first_user_title and record.type == "message" and type(record.message) == "table" and record.message.role == "user" then
			first_user_title = fallback_title(record_message_text(record.message))
		end
	end

	if looks_like_bad_model_title(candidate.title) and first_user_title then
		candidate.title = first_user_title
	end
	candidate.title = candidate.title or first_user_title
	return candidate
end

local function canonical_session_path(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	return vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
end

local function regular_session_path(path)
	if type(path) == "string" and path:sub(-#ARCHIVED_SUFFIX) == ARCHIVED_SUFFIX then
		return path:sub(1, -#ARCHIVED_SUFFIX - 1)
	end
	return path
end

local function archived_session_path(path)
	return regular_session_path(path) .. ARCHIVED_SUFFIX
end

local function workspace_root()
	return vim.env.PI_WORKSPACE_ROOT
		or ((vim.env.XDG_STATE_HOME or (vim.fn.expand("~") .. "/.local/state")) .. "/pi/workspaces")
end

local function workspace_records()
	local records = {}
	local records_dir = vim.fn.fnamemodify(workspace_root(), ":p") .. "/records"
	for _, path in ipairs(vim.fn.globpath(records_dir, "*.json", false, true)) do
		local ok, lines = pcall(vim.fn.readfile, path)
		local record = ok and decode_record(table.concat(lines, "\n"))
		if record and record.version == 1 and (record.kind == "task" or record.kind == "child") then
			table.insert(records, record)
		end
	end
	return records
end

local function read_session_history(path)
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		return nil
	end
	local header = decode_record(lines[1] or "")
	if not header or header.type ~= "session" or type(header.id) ~= "string" then
		return nil
	end
	local entries = {}
	for index = 2, #lines do
		if vim.trim(lines[index]) ~= "" then
			local entry = decode_record(lines[index])
			if not entry or type(entry.id) ~= "string" or entries[entry.id] then
				return nil
			end
			-- Renaming an old session does not create independent conversation history.
			if entry.type ~= "session_info" then
				entries[entry.id] = entry
			end
		end
	end
	return { parent = canonical_session_path(header.parentSession), entries = entries }
end

local function has_new_activity(previous, successor)
	for id, entry in pairs(successor.entries) do
		if not previous.entries[id] then
			if entry.type == "custom_message" and entry.customType == "workspace-continuation" then
				return true
			end
			local message = entry.type == "message" and entry.message
			if type(message) == "table" and (message.role == "user" or message.role == "assistant") then
				return true
			end
		end
	end
	return false
end

local function filter_workspace_sessions(session_candidates)
	local by_path = {}
	for _, candidate in ipairs(session_candidates) do
		by_path[canonical_session_path(candidate.path)] = candidate
	end
	local histories = {}
	local hidden = {}
	local function history(path)
		if histories[path] == nil then
			histories[path] = read_session_history(path) or false
		end
		return histories[path]
	end
	local function supersede(source, target, returned)
		source, target = canonical_session_path(source), canonical_session_path(target)
		if not source or not target or source == target or not by_path[source] or not by_path[target] then
			return
		end
		local previous, successor = history(source), history(target)
		if not previous or not successor or successor.parent ~= source then
			return
		end
		-- The file is forked before switching. Its existence alone does not prove entry succeeded.
		if not returned and not has_new_activity(previous, successor) then
			return
		end
		for id, entry in pairs(previous.entries) do
			if not vim.deep_equal(entry, successor.entries[id]) then
				return
			end
		end
		hidden[source] = true
	end

	for _, record in ipairs(workspace_records()) do
		if record.kind == "task" then
			supersede(record.sourceSessionFile, record.targetSessionFile, false)
			-- Task integration finishes after switching back. Discard/cleanup can also happen
			-- from another session, so those states require activity in the continuation.
			if record.lifecycle == "integrated" or record.lifecycle == "discarded" or record.lifecycle == "cleanup_failed" then
				supersede(record.targetSessionFile, record.continuationSessionFile, record.lifecycle == "integrated")
			end
		end
	end

	return vim.tbl_filter(function(candidate)
		return not hidden[canonical_session_path(candidate.path)]
	end, session_candidates)
end

local function session_dirs(ctx)
	local dirs = {}
	local seen_dirs = {}
	local function add_dir(path)
		if not path or path == "" then
			return
		end
		path = vim.fn.expand(path)
		local resolved = vim.fn.resolve(path)
		if resolved == "" then
			resolved = path
		end
		if vim.fn.isdirectory(path) == 1 and not seen_dirs[resolved] then
			seen_dirs[resolved] = true
			table.insert(dirs, path)
		end
	end

	add_dir(ctx.config.session_dir)
	if ctx.config.agent_dir and ctx.config.agent_dir ~= "" then
		add_dir(vim.fn.expand(ctx.config.agent_dir) .. "/sessions")
	end
	add_dir(dirname(ctx.state.session_file))
	for _, dir in ipairs(ctx.config.session_dirs or {}) do
		add_dir(dir)
	end
	return dirs
end

local function session_paths(ctx, archived)
	local paths = {}
	local seen_files = {}
	local pattern = archived and ("**/*.jsonl" .. ARCHIVED_SUFFIX) or "**/*.jsonl"
	for _, dir in ipairs(session_dirs(ctx)) do
		for _, path in ipairs(vim.fn.globpath(dir, pattern, false, true)) do
			local resolved = vim.fn.resolve(path)
			if resolved == "" then
				resolved = path
			end
			if not seen_files[resolved] then
				seen_files[resolved] = true
				table.insert(paths, path)
			end
		end
	end
	return paths
end

local function candidates(ctx, opts)
	opts = opts or {}
	local allowed_paths = nil
	if opts.paths then
		allowed_paths = {}
		for _, path in ipairs(opts.paths) do
			allowed_paths[canonical_session_path(path)] = true
		end
	end

	local result = {}
	for _, path in ipairs(session_paths(ctx, opts.archived)) do
		if not allowed_paths or allowed_paths[canonical_session_path(path)] then
			table.insert(result, read_candidate(path))
		end
	end

	if not opts.archived and not opts.include_superseded then
		result = filter_workspace_sessions(result)
	end
	table.sort(result, function(a, b)
		return a.mtime > b.mtime
	end)
	return result
end

local function item_title(candidate)
	return candidate.title or vim.fn.fnamemodify(regular_session_path(candidate.path), ":t")
end

local function item_label(candidate)
	local time = os.date("%Y-%m-%d %H:%M", candidate.mtime)
	if candidate.cwd and candidate.cwd ~= "" then
		return string.format("%s  pwd: %s  %s", item_title(candidate), vim.fn.fnamemodify(candidate.cwd, ":~"), time)
	end
	return string.format("%s  %s", item_title(candidate), time)
end

local function protected_session_paths(ctx)
	local protected = {}
	local function add(path)
		path = canonical_session_path(regular_session_path(path))
		if path then
			protected[path] = true
		end
	end

	add(ctx.state.session_file)
	add(ctx.state.pending_session_file)
	for _, record in ipairs(workspace_records()) do
		if record.retained == true then
			add(record.sourceSessionFile)
			add(record.targetSessionFile)
			add(record.continuationSessionFile)
		end
	end
	return protected
end

local function partition_protected(ctx, selected)
	local protected_paths = protected_session_paths(ctx)
	local allowed = {}
	local skipped = {}
	for _, candidate in ipairs(selected) do
		local path = canonical_session_path(regular_session_path(candidate.path))
		if path and protected_paths[path] then
			table.insert(skipped, candidate)
		else
			table.insert(allowed, candidate)
		end
	end
	return allowed, skipped
end

local function selected_title(selected)
	if #selected == 1 then
		return " " .. item_title(selected[1])
	end
	return ""
end

local function confirm(prompt, callback)
	local choice
	local choice_received = false
	local picker_closed = false
	local dispatched = false
	local function dispatch()
		if dispatched or not choice_received or not picker_closed then
			return
		end
		dispatched = true
		vim.schedule(function()
			callback(choice == "Yes")
		end)
	end

	vim.ui.select({ "Yes", "No" }, {
		prompt = prompt,
		on_close = function()
			picker_closed = true
			dispatch()
		end,
	}, function(selected)
		choice = selected
		choice_received = true
		dispatch()
	end)
end

local function rename_sessions(selected, archive)
	local succeeded = {}
	local failed = {}
	for _, candidate in ipairs(selected) do
		local target = archive and archived_session_path(candidate.path) or regular_session_path(candidate.path)
		if vim.fn.filereadable(target) == 1 then
			table.insert(failed, string.format("%s: destination already exists", item_title(candidate)))
		else
			local ok, err = (vim.uv or vim.loop).fs_rename(candidate.path, target)
			if ok then
				candidate.path = target
				table.insert(succeeded, candidate)
			else
				table.insert(failed, string.format("%s: %s", item_title(candidate), err or "rename failed"))
			end
		end
	end
	return succeeded, failed
end

local function trash_command()
	if vim.fn.executable("trash") == 1 then
		return { "trash" }
	end
	if vim.fn.executable("gio") == 1 then
		return { "gio", "trash" }
	end
	return nil
end

local function delete_sessions(selected, command)
	local failed = {}
	if command then
		local args = vim.deepcopy(command)
		for _, candidate in ipairs(selected) do
			table.insert(args, candidate.path)
		end
		local result = vim.system(args, { text = true }):wait()
		if result.code ~= 0 then
			local detail = vim.trim(result.stderr or "")
			for _, candidate in ipairs(selected) do
				if vim.fn.filereadable(candidate.path) == 1 then
					table.insert(failed, string.format("%s: %s", item_title(candidate), detail ~= "" and detail or "trash command failed"))
				end
			end
		end
		return failed
	end

	for _, candidate in ipairs(selected) do
		if vim.fn.delete(candidate.path) ~= 0 then
			table.insert(failed, item_title(candidate) .. ": delete failed")
		end
	end
	return failed
end

local function notify_failures(ctx, failures)
	if #failures == 0 then
		return
	end
	local message = table.concat(vim.list_slice(failures, 1, 3), "\n")
	if #failures > 3 then
		message = message .. string.format("\n...and %d more", #failures - 3)
	end
	ctx.ui.notify(message, vim.log.levels.ERROR)
end

local function attach_session(ctx, choice)
	local state = ctx.state
	local function refresh_attached_session(message)
		state.is_retrying = false
		state.pending_retry_error = nil
		state.session_file = choice.path
		state.session_name = choice.title
		state.tree_leaf_id = nil
		ctx.rpc.send({ type = "get_state" }, function(state_event)
			if state_event.success and state_event.data then
				ctx.session.apply_state(state_event.data)
				ctx.actions.refresh_session_stats()
				ctx.rpc.send({ type = "prompt", message = "/pi-workspace-publish" })
			end
			ctx.actions.refresh_messages()
			ctx.ui.notify(message)
		end)
	end

	local function proceed()
		if not (state.job and state.job > 0) then
			state.pending_session_file = choice.path
			refresh_attached_session("Attached session")
			return
		end
		ctx.rpc.send({ type = "switch_session", sessionPath = choice.path }, function(event)
			if event.success and not (event.data and event.data.cancelled) then
				refresh_attached_session("Switched session")
			else
				ctx.ui.notify("Session switch cancelled or failed", vim.log.levels.ERROR)
			end
		end)
	end

	guard.confirm_abort_active_run(ctx, "Switching sessions", proceed)
end

local function decode_selection(items, by_id)
	local selected = {}
	local seen = {}
	for _, item in ipairs(items or {}) do
		local id = item:match("^(%d+)\t")
		local candidate = id and by_id[id]
		if candidate and not seen[id] then
			seen[id] = true
			table.insert(selected, candidate)
		end
	end
	return selected
end

local function session_previewer(by_id)
	return {
		_ctor = function()
			local previewer = require("fzf-lua.previewer.builtin").buffer_or_file:extend()
			function previewer:entry_to_file(entry)
				local id = entry and entry:match("^(%d+)\t")
				local candidate = id and by_id[id]
				if not candidate then
					return {}
				end
				return { path = candidate.path, filetype = "json" }
			end
			return previewer
		end,
	}
end

local function picker_title(view, stale)
	if stale then
		return " Pi sessions to archive "
	end
	return view == "archived" and " Pi archived sessions " or " Pi sessions "
end

local function reopen(ctx, opts)
	vim.schedule(function()
		M.pick(ctx, opts)
	end)
end

function M.pick(ctx, opts)
	opts = opts or {}
	local view = opts.view == "archived" and "archived" or "regular"
	local archived = view == "archived"
	local session_candidates = candidates(ctx, {
		archived = archived,
		paths = opts.paths,
		include_superseded = opts.include_superseded,
	})
	if #session_candidates == 0 then
		if not opts.paths and not archived and #session_paths(ctx, true) > 0 then
			ctx.ui.notify("No regular Pi sessions found; showing archived sessions.")
			M.pick(ctx, { view = "archived" })
			return
		end
		if not opts.paths and archived and #session_paths(ctx, false) > 0 then
			ctx.ui.notify("No archived Pi sessions found; showing regular sessions.")
			M.pick(ctx, { view = "regular" })
			return
		end
		local message = archived and "No archived Pi sessions found." or "No Pi session files found."
		ctx.ui.notify(message, vim.log.levels.WARN)
		return
	end

	local entries = {}
	local by_id = {}
	for index, candidate in ipairs(session_candidates) do
		local id = string.format("%06d", index)
		by_id[id] = candidate
		table.insert(entries, id .. "\t" .. item_label(candidate))
	end

	local reopen_opts = vim.deepcopy(opts)
	reopen_opts.view = view
	local function selected_candidates(items)
		return decode_selection(items, by_id)
	end
	local function reopen_current()
		reopen(ctx, reopen_opts)
	end
	local function archive_or_restore(items)
		local selected = selected_candidates(items)
		if #selected == 0 then
			reopen_current()
			return
		end
		local allowed, skipped = partition_protected(ctx, selected)
		if #skipped > 0 then
			ctx.ui.notify(string.format("Skipped %d active or workspace-linked session(s).", #skipped), vim.log.levels.WARN)
		end
		if #allowed == 0 then
			reopen_current()
			return
		end
		local verb = archived and "Unarchive" or "Archive"
		local noun = #allowed == 1 and "session" or "sessions"
		confirm(string.format("%s %d %s?%s", verb, #allowed, noun, selected_title(allowed)), function(confirmed)
			if not confirmed then
				reopen_current()
				return
			end
			local succeeded, failures = rename_sessions(allowed, not archived)
			if #succeeded > 0 then
				ctx.ui.notify(string.format("%s %d session(s).", archived and "Unarchived" or "Archived", #succeeded))
			end
			notify_failures(ctx, failures)
			reopen_current()
		end)
	end
	local function delete_selected(items)
		local selected = selected_candidates(items)
		if #selected == 0 then
			reopen_current()
			return
		end
		local allowed, skipped = partition_protected(ctx, selected)
		if #skipped > 0 then
			ctx.ui.notify(string.format("Skipped %d active or workspace-linked session(s).", #skipped), vim.log.levels.WARN)
		end
		if #allowed == 0 then
			reopen_current()
			return
		end
		local command = trash_command()
		local action = command and "Move" or "Permanently delete"
		local destination = command and " to trash" or ""
		local noun = #allowed == 1 and "session" or "sessions"
		confirm(string.format("%s %d %s%s?%s", action, #allowed, noun, destination, selected_title(allowed)), function(confirmed)
			if not confirmed then
				reopen_current()
				return
			end
			local failures = delete_sessions(allowed, command)
			local deleted = #allowed - #failures
			if deleted > 0 then
				ctx.ui.notify(string.format("%s %d session(s).", command and "Trashed" or "Deleted", deleted))
			end
			notify_failures(ctx, failures)
			reopen_current()
		end)
	end
	local function select_session(items)
		local choice = selected_candidates(items)[1]
		if not choice then
			return
		end
		if not archived then
			attach_session(ctx, choice)
			return
		end
		local succeeded, failures = rename_sessions({ choice }, false)
		if #succeeded == 1 then
			attach_session(ctx, succeeded[1])
		else
			notify_failures(ctx, failures)
			reopen_current()
		end
	end

	local keymap = { fzf = { ["ctrl-a"] = "toggle-all" } }
	if opts.select_all then
		keymap.fzf.start = "select-all"
	end
	require("fzf-lua").fzf_exec(entries, {
		prompt = archived and "Archived > " or "Sessions > ",
		winopts = { title = picker_title(view, opts.paths ~= nil), title_pos = "left" },
		previewer = session_previewer(by_id),
		fzf_opts = {
			["--multi"] = true,
			["--delimiter"] = "[\t]",
			["--with-nth"] = "2..",
		},
		keymap = keymap,
		actions = {
			enter = { fn = select_session, header = archived and "unarchive and resume" or "resume" },
			["ctrl-r"] = { fn = archive_or_restore, header = archived and "unarchive" or "archive" },
			["ctrl-x"] = { fn = delete_selected, header = "trash" },
			["ctrl-g"] = {
				fn = function()
					reopen(ctx, { view = archived and "regular" or "archived" })
				end,
				header = archived and "show regular" or "show archived",
			},
		},
	})
end

local function reminder_state_path()
	return vim.fn.stdpath("state") .. "/pi-nvim/session-archive-reminder.json"
end

local function read_reminder_state()
	local ok, lines = pcall(vim.fn.readfile, reminder_state_path())
	if not ok then
		return nil
	end
	return decode_record(table.concat(lines, "\n"))
end

local function write_reminder_state(timestamp)
	local path = reminder_state_path()
	local state_dir = vim.fn.fnamemodify(path, ":h")
	local ok, err = pcall(function()
		if vim.fn.mkdir(state_dir, "p") == 0 and vim.fn.isdirectory(state_dir) == 0 then
			error("could not create state directory")
		end
		if vim.fn.writefile({ json.encode({ version = 1, prompted_at = timestamp }) }, path) ~= 0 then
			error("could not write reminder state")
		end
	end)
	return ok, err
end

local function stale_session_paths(ctx, timestamp)
	local stale_before = timestamp - (ARCHIVE_AFTER_DAYS * DAY_SECONDS)
	local protected = protected_session_paths(ctx)
	local stale = {}
	for _, path in ipairs(session_paths(ctx, false)) do
		local canonical = canonical_session_path(path)
		local mtime = vim.fn.getftime(path)
		if mtime >= 0 and mtime < stale_before and not protected[canonical] then
			table.insert(stale, path)
		end
	end
	return stale
end

function M.maybe_prompt_archive(ctx)
	if reminder_checked then
		return
	end
	reminder_checked = true

	local now = os.time()
	local state = read_reminder_state()
	if state and type(state.prompted_at) == "number" and now - state.prompted_at < ARCHIVE_REMINDER_DAYS * DAY_SECONDS then
		return
	end
	local stale = stale_session_paths(ctx, now)
	if #stale == 0 then
		return
	end
	local ok, err = write_reminder_state(now)
	if not ok then
		ctx.ui.notify("Could not save the Pi session archive reminder: " .. tostring(err), vim.log.levels.WARN)
		return
	end
	confirm(string.format("Review %d Pi session(s) inactive for over %d days for archiving?", #stale, ARCHIVE_AFTER_DAYS), function(confirmed)
		if not confirmed then
			return
		end
		M.pick(ctx, {
			view = "regular",
			paths = stale,
			include_superseded = true,
			select_all = true,
		})
	end)
end

return M

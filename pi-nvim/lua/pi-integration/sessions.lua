local guard = require("pi-integration.utils.guard")
local json = require("pi-integration.utils.json")
local message_utils = require("pi-integration.utils.message")

local M = {}

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

	return candidate
end

local function candidates(ctx)
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

	local result = {}
	local seen_files = {}
	for _, dir in ipairs(dirs) do
		for _, path in ipairs(vim.fn.globpath(dir, "**/*.jsonl", false, true)) do
			local resolved = vim.fn.resolve(path)
			if resolved == "" then
				resolved = path
			end
			if not seen_files[resolved] then
				seen_files[resolved] = true
				table.insert(result, read_candidate(path))
			end
		end
	end

	table.sort(result, function(a, b)
		return a.mtime > b.mtime
	end)
	return result
end

local function item_label(candidate)
	local title = candidate.title or vim.fn.fnamemodify(candidate.path, ":t")
	local time = os.date("%Y-%m-%d %H:%M", candidate.mtime)
	if candidate.cwd and candidate.cwd ~= "" then
		return string.format("%s  pwd: %s  %s", title, vim.fn.fnamemodify(candidate.cwd, ":~"), time)
	end
	return string.format("%s  %s", title, time)
end

function M.pick(ctx)
	local state = ctx.state
	local session_candidates = candidates(ctx)
	if #session_candidates == 0 then
		ctx.ui.notify("No session files found. Set PI_SESSION_DIR if your Pi sessions live elsewhere.", vim.log.levels.WARN)
		return
	end

	vim.ui.select(session_candidates, {
		prompt = "Pi session",
		format_item = item_label,
	}, function(choice)
		if not choice then
			return
		end
		local function proceed()
			if not (state.job and state.job > 0) then
				state.pending_session_file = choice.path
				state.session_file = choice.path
				state.session_name = choice.title
				state.tree_leaf_id = nil
				ctx.session.render_messages(ctx.session.load_messages_from_file(choice.path))
				ctx.ui.notify("Selected session. Pi will attach to it when you send a message.")
				return
			end
			ctx.rpc.send({ type = "switch_session", sessionPath = choice.path }, function(event)
				if event.success and not (event.data and event.data.cancelled) then
					state.is_retrying = false
					state.pending_retry_error = nil
					state.session_file = choice.path
					state.tree_leaf_id = nil
					ctx.rpc.send({ type = "get_state" }, function(state_event)
						if state_event.success and state_event.data then
							ctx.session.apply_state(state_event.data)
							ctx.actions.refresh_session_stats()
						end
					end)
					ctx.actions.refresh_messages()
					ctx.ui.notify("Switched session")
				else
					ctx.ui.notify("Session switch cancelled or failed", vim.log.levels.ERROR)
				end
			end)
		end

		guard.confirm_abort_active_run(ctx, "Switching sessions", proceed)
	end)
end

return M

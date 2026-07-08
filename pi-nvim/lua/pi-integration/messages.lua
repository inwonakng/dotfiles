local M = {}

local json = require("pi-integration.utils.json")
local pi_skills = require("pi-integration.skills")

function M.decode_session_record(line)
	return json.decode_object(line)
end

local function custom_message_from_record(record)
	return {
		role = "custom",
		customType = record.customType,
		content = record.content,
		display = record.display,
		details = record.details,
		timestamp = record.timestamp,
	}
end

local function apply_session_record_metadata(ctx, records)
	for _, record in ipairs(records or {}) do
		if record.type == "session_info" and type(record.name) == "string" then
			ctx.state.session_name = record.name
		elseif record.type == "model_change" then
			ctx.session.set_model_metadata(record.provider or record.providerId or record.providerName, record.modelId or record.model or record.id)
		elseif record.type == "thinking_level_change" and type(record.thinkingLevel) == "string" then
			ctx.state.thinking_level = record.thinkingLevel
		end
	end
end

function M.load_session_messages_from_file(ctx, path)
	local fallback_messages = {}
	local all_records = {}
	local by_id = {}
	local leaf_id = nil
	if not path or vim.fn.filereadable(path) ~= 1 then
		return fallback_messages
	end
	for _, line in ipairs(vim.fn.readfile(path)) do
		local record = M.decode_session_record(line)
		if record then
			table.insert(all_records, record)
		end
		if record and record.id then
			by_id[record.id] = record
			leaf_id = record.id
		end
		if record and record.type == "message" and record.message then
			table.insert(fallback_messages, record.message)
		elseif record and record.type == "custom_message" and record.display ~= false then
			table.insert(fallback_messages, custom_message_from_record(record))
		end
	end

	local branch = {}
	local seen = {}
	local id = leaf_id
	while id and by_id[id] and not seen[id] do
		seen[id] = true
		local record = by_id[id]
		table.insert(branch, 1, record)
		id = record.parentId
	end

	apply_session_record_metadata(ctx, #branch > 0 and branch or all_records)

	local messages = {}
	for _, record in ipairs(branch) do
		if record.type == "message" and record.message then
			table.insert(messages, record.message)
		elseif record.type == "custom_message" and record.display ~= false then
			table.insert(messages, custom_message_from_record(record))
		end
	end
	return #messages > 0 and messages or fallback_messages
end

local function message_role_title(message)
	local role = message.role or message.type or "message"
	if role == "toolResult" then
		return "Tool"
	end
	return role:gsub("^%l", string.upper)
end

local function add_message_separator(lines, has_body)
	if has_body then
		vim.list_extend(lines, { "", "---", "" })
	else
		table.insert(lines, "")
	end
end

local function remove_trailing_blank(lines)
	if lines[#lines] == "" then
		table.remove(lines)
	end
end

local function is_trace_like(kind)
	return kind == "tool" or kind == "thinking" or kind == "skill"
end

local function assistant_trace_only_thinking(message)
	local content = message.content
	if type(content) ~= "table" then
		return nil
	end

	local thinking = {}
	for _, item in ipairs(content) do
		if type(item) == "string" then
			if item ~= "" then
				return nil
			end
		elseif type(item) == "table" then
			if item.type == "thinking" then
				local text = item.thinking or item.text or ""
				if text ~= "" then
					table.insert(thinking, text)
				end
			elseif item.type == "text" or item.text then
				local text = item.text or item.content or item.delta or ""
				if text ~= "" then
					return nil
				end
			end
		end
	end

	return #thinking > 0 and thinking or nil
end

local function is_spawn_tool_name(name)
	return name == "spawn"
end

local function message_run_id(message)
	local details = type(message) == "table" and type(message.details) == "table" and message.details or nil
	if not details then
		return nil
	end
	return details.runId or details.id
end

local function bind_spawn_line(ctx, message, output_id, line)
	if ctx.tools.bind_spawn_run then
		ctx.tools.bind_spawn_run(message.details, output_id, line)
	end
end

local function update_existing_spawn_line(ctx, lines, message, text)
	local id = message_run_id(message)
	if type(id) ~= "string" or id == "" then
		return false
	end
	local line = ctx.state.spawn_run_lines and ctx.state.spawn_run_lines[id]
	if not line or not lines[line] or not ctx.tools.store_or_update_spawn_run_output then
		return false
	end
	local output_id = ctx.tools.store_or_update_spawn_run_output(message.details, text)
	if not output_id then
		return false
	end
	bind_spawn_line(ctx, message, output_id, line)
	lines[line] = ctx.tools.summary_lines(output_id)[1]
	return true
end

local function append_tool_summary(ctx, lines, items, message)
	local name = message.toolName or "tool"
	local text = ctx.messages.extract_text(message)
	if not text or text == "" then
		return false
	end
	local output_id = ctx.tools.store_output(name, text, nil, message.details, message)
	vim.list_extend(lines, ctx.tools.summary_lines(output_id))
	local line = #lines
	if is_spawn_tool_name(name) then
		bind_spawn_line(ctx, message, output_id, line)
	end
	table.insert(lines, "")
	table.insert(items, {
		kind = "tool",
		start_line = line,
		end_line = line,
		output_id = output_id,
	})
	return true
end

local function spawn_custom_tool_name(message)
	if type(message) ~= "table" or message.role ~= "custom" then
		return nil
	end
	if message.customType == "spawn_completion" then
		return "spawn"
	elseif message.customType == "spawn_control_result" then
		return "spawn_control"
	end
	return nil
end

local function append_thinking_summary(ctx, lines, items, text)
	if type(text) ~= "string" or text == "" then
		return false
	end
	local output_id = ctx.thinking.store_output(text)
	vim.list_extend(lines, ctx.thinking.summary_lines(output_id, false))
	local line = #lines
	table.insert(lines, "")
	table.insert(items, {
		kind = "thinking",
		start_line = line,
		end_line = line,
		output_id = output_id,
	})
	return true
end

local function append_skill_load_summaries(ctx, lines, items, loads, has_body, previous_kind)
	if type(loads) ~= "table" or #loads == 0 then
		return false
	end
	if has_body and is_trace_like(previous_kind) then
		remove_trailing_blank(lines)
	else
		add_message_separator(lines, has_body)
	end
	for _, load in ipairs(loads) do
		local output_id = ctx.skills.store_prompt(load)
		vim.list_extend(lines, ctx.skills.summary_lines(output_id))
		local line = #lines
		table.insert(items, {
			kind = "skill",
			start_line = line,
			end_line = line,
			output_id = output_id,
		})
	end
	table.insert(lines, "")
	return true
end

local function append_text_message(lines, message, text, has_body)
	local text_lines = vim.split(text, "\n", { plain = true })
	add_message_separator(lines, has_body)
	table.insert(lines, "## " .. message_role_title(message))
	table.insert(lines, "")
	vim.list_extend(lines, text_lines)
end

local function append_assistant_blocks(ctx, lines, items, message, has_body, options)
	options = options or {}
	local content = message.content
	if type(content) ~= "table" then
		local text = ctx.messages.extract_text(message)
		if text and text ~= "" then
			append_text_message(lines, message, text, has_body)
			return true, "message"
		end
		return false, nil
	end

	local started = false
	local appended = false
	local pending_text = {}
	local last_rendered_kind = nil

	local function ensure_assistant_message()
		if started then
			return
		end
		if options.continue_trace then
			started = true
			return
		end
		add_message_separator(lines, has_body)
		table.insert(lines, "## " .. message_role_title(message))
		table.insert(lines, "")
		started = true
	end

	local function ensure_inline_gap(kind)
		if
			is_trace_like(kind)
			and (is_trace_like(last_rendered_kind) or (not appended and options.continue_trace and is_trace_like(options.previous_kind)))
		then
			remove_trailing_blank(lines)
		elseif appended and lines[#lines] ~= "" then
			table.insert(lines, "")
		end
	end

	local function flush_text()
		local text = table.concat(pending_text, "")
		pending_text = {}
		if text == "" then
			return
		end
		ensure_assistant_message()
		ensure_inline_gap("message")
		vim.list_extend(lines, vim.split(text, "\n", { plain = true }))
		appended = true
		last_rendered_kind = "message"
	end

	for _, item in ipairs(content) do
		if type(item) == "string" then
			table.insert(pending_text, item)
		elseif type(item) == "table" then
			if item.type == "thinking" then
				flush_text()
				local thinking = item.thinking or item.text or ""
				if thinking ~= "" then
					ensure_assistant_message()
					ensure_inline_gap("thinking")
					if append_thinking_summary(ctx, lines, items, thinking) then
						appended = true
						last_rendered_kind = "thinking"
					end
				end
			elseif item.type == "text" or item.text then
				table.insert(pending_text, item.text or item.content or item.delta or "")
			end
		end
	end
	flush_text()
	return appended, last_rendered_kind
end

function M.collect_message_lines(ctx, messages)
	local lines = ctx.transcript.metadata_lines()
	local items = {}
	local has_body = false
	local last_rendered_kind = nil

	for _, message in ipairs(messages or {}) do
		local role = message.role or message.type
		local appended = false
		local rendered_kind = nil
		if role == "toolResult" then
			local name = message.toolName or "tool"
			local text = ctx.messages.extract_text(message) or ""
			if pi_skills.tool_result_skill_name(ctx.state, message) then
				ctx.skills.apply_tool_result(message)
				appended = false
			elseif is_spawn_tool_name(name) and update_existing_spawn_line(ctx, lines, message, text) then
				appended = false
			elseif has_body and is_trace_like(last_rendered_kind) then
				remove_trailing_blank(lines)
				appended = append_tool_summary(ctx, lines, items, message)
				rendered_kind = appended and "tool" or nil
			else
				add_message_separator(lines, has_body)
				appended = append_tool_summary(ctx, lines, items, message)
				rendered_kind = appended and "tool" or nil
			end
		elseif role == "assistant" then
			ctx.tools.record_calls(message)
			local skill_loads = pi_skills.collect_loads(ctx.state, message)
			local thinking = assistant_trace_only_thinking(message)
			appended, rendered_kind = append_assistant_blocks(ctx, lines, items, message, has_body, {
				continue_trace = thinking ~= nil and is_trace_like(last_rendered_kind),
				previous_kind = last_rendered_kind,
			})
			if appended then
				has_body = true
				last_rendered_kind = rendered_kind
			end
			if append_skill_load_summaries(ctx, lines, items, skill_loads, has_body, last_rendered_kind) then
				appended = true
				rendered_kind = "skill"
			end
		elseif role == "custom" then
			if message.display == false then
				appended = false
			elseif spawn_custom_tool_name(message) then
				local name = spawn_custom_tool_name(message)
				local text = name == "spawn" and "" or (ctx.messages.extract_text(message) or "")
				local details = type(message.details) == "table" and message.details or nil
				if details and type(details.runs) == "table" then
					for _, run in ipairs(details.runs) do
						update_existing_spawn_line(ctx, lines, { details = run }, nil)
					end
				else
					update_existing_spawn_line(ctx, lines, message, text)
				end
				appended = false
			else
				local text = ctx.messages.extract_text(message)
				if text and text ~= "" then
					append_text_message(lines, message, text, has_body)
					appended = true
					rendered_kind = "message"
				end
			end
		else
			local text = ctx.messages.extract_text(message)
			if text and text ~= "" then
				append_text_message(lines, message, text, has_body)
				appended = true
				rendered_kind = "message"
			end
		end
		if appended then
			has_body = true
			last_rendered_kind = rendered_kind
		end
	end

	return lines, items
end

return M

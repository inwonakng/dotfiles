local M = {}

local function normalized_path(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	return path:gsub("\\", "/")
end

function M.skill_name_from_read_path(path)
	local normalized = normalized_path(path)
	if not normalized then
		return nil
	end
	if not normalized:find("/skills/", 1, true) then
		return nil
	end

	local parent = normalized:match("^.+/([^/]+)/SKILL%.md$")
	if parent then
		return parent
	end

	local basename = normalized:match("/skills/([^/]+)%.md$")
	if basename then
		return basename
	end

	return nil
end

local function tool_call_id(item)
	return item.id or item.toolCallId or item.tool_call_id or item.callId
end

local function tool_call_arguments(item)
	local args = item.arguments or item.args or item.input
	if type(args) == "table" then
		return args
	end
	return nil
end

local function skill_load_from_content_item(item)
	if type(item) ~= "table" then
		return nil
	end
	if item.type ~= "toolCall" and item.type ~= "tool_call" then
		return nil
	end
	local name = item.name or item.toolName or item.tool_name
	if name ~= "read" then
		return nil
	end
	local args = tool_call_arguments(item)
	local path = args and args.path
	local skill_name = M.skill_name_from_read_path(path)
	if not skill_name then
		return nil
	end
	return {
		name = skill_name,
		path = path,
		tool_call_id = tool_call_id(item),
	}
end

function M.reset(state)
	state.skill_tool_calls = {}
end

function M.collect_loads(state, message)
	state.skill_tool_calls = state.skill_tool_calls or {}
	local loads = {}
	if type(message) ~= "table" or type(message.content) ~= "table" then
		return loads
	end

	for _, item in ipairs(message.content) do
		local load = skill_load_from_content_item(item)
		if load then
			if load.tool_call_id then
				state.skill_tool_calls[load.tool_call_id] = load.name
			end
			table.insert(loads, load)
		end
	end
	return loads
end

function M.tool_result_skill_name(state, message)
	if type(message) ~= "table" then
		return nil
	end
	local id = message.toolCallId or message.tool_call_id or message.id
	if not id then
		return nil
	end
	local calls = state.skill_tool_calls or {}
	return calls[id]
end

function M.summary_lines(load)
	local name = type(load) == "table" and load.name or load
	return { "> 󰢱 Using skill: " .. tostring(name or "unknown") }
end

return M

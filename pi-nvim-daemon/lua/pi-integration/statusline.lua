local M = {}

local function non_null(value)
	return value ~= nil and value ~= vim.NIL
end

local function format_count(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fk", value / 1000)
	end
	return tostring(value)
end

local function format_session_stats(state)
	local stats = state.session_stats
	if not stats then
		return "tokens: --"
	end

	local tokens = stats.tokens or {}
	local parts = {
		"↑" .. format_count(tokens.input),
		"↓" .. format_count(tokens.output),
	}

	-- Pi core currently reports cacheRead/cacheWrite as cumulative per-request
	-- token events. For statusline purposes, show the session cache footprint
	-- instead: the largest cache read/write reported by any single model turn.
	local cache_read = tonumber(tokens.sessionCacheRead or tokens.cacheRead) or 0
	local cache_write = tonumber(tokens.sessionCacheWrite or tokens.cacheWrite) or 0
	if cache_read > 0 or cache_write > 0 then
		table.insert(parts, "R" .. format_count(cache_read))
		table.insert(parts, "W" .. format_count(cache_write))
	end

	local context = stats.contextUsage
	if context then
		local context_tokens = non_null(context.tokens) and format_count(context.tokens) or "?"
		local context_window = non_null(context.contextWindow) and format_count(context.contextWindow) or "?"
		table.insert(parts, "ctx " .. context_tokens .. "/" .. context_window)
	end

	if non_null(stats.cost) then
		table.insert(parts, string.format("$%.2f", stats.cost))
	end

	return table.concat(parts, "·")
end

local function statusline_escape(text)
	return tostring(text or ""):gsub("%%", "%%%%")
end

local function truncate_plain_to_width(text, width)
	if vim.fn.strdisplaywidth(text) <= width then
		return text
	end

	local result = ""
	for _, char in ipairs(vim.fn.split(text, "\\zs")) do
		local next_result = result .. char
		if vim.fn.strdisplaywidth(next_result) > width then
			break
		end
		result = next_result
	end
	return result
end

local function mode_statusline_highlight(mode)
	if mode == "readonly" then
		return "%#PiModeReadonly#"
	elseif mode == "write" then
		return "%#PiModeWrite#"
	end
	return "%#PiModeUnknown#"
end

local function mode_statusline_label(mode)
	if mode == "readonly" then
		return " "
	elseif mode == "write" then
		return "󱇧 "
	end
	return tostring(mode or "--")
end

local function current_model_statusline_label(ctx)
	local model = ctx.state.model_id or ctx.config.model
	local provider = ctx.state.provider or ctx.config.provider
	if type(model) ~= "string" or model == "" then
		return "--"
	end
	if type(provider) == "string" and provider ~= "" and not model:find("/", 1, true) then
		return provider .. "/" .. model
	end
	return model
end

local function current_thinking_level_label(state)
	local level = state.thinking_level
	if type(level) ~= "string" or level == "" then
		return nil
	end
	return level
end

local function spawn_statusline_label(state)
	local count = tonumber(state.spawn_running_count) or 0
	if count <= 0 then
		return ""
	end
	return " 󰇥" .. tostring(count)
end

local function thinking_statusline_highlight(level)
	if level == "off" then
		return "%#PiThinkingOff#"
	elseif level == "minimal" then
		return "%#PiThinkingMinimal#"
	elseif level == "low" then
		return "%#PiThinkingLow#"
	elseif level == "medium" then
		return "%#PiThinkingMedium#"
	elseif level == "high" then
		return "%#PiThinkingHigh#"
	elseif level == "xhigh" then
		return "%#PiThinkingXhigh#"
	end
	return "%#PiUsageStats#"
end

local function notification_statusline_label(status)
	if status == "notify on" then
		return "󰂞 "
	elseif status == "notify off" then
		return "󰂛 "
	end
	return tostring(status or "")
end

local function notification_statusline_highlight(status)
	if status == "notify on" then
		return "%#PiNotifyOn#"
	elseif status == "notify off" then
		return "%#PiNotifyOff#"
	end
	return "%#PiUsageStats#"
end

function M.render(ctx)
	local state = ctx.state
	local mode = state.access_mode or "--"
	local mode_text = mode_statusline_label(mode)
	local mode_prefix = " "
	local mode_suffix = ""
	local mode_label = mode_prefix .. mode_text .. mode_suffix
	local status_delimiter = "·"
	local notification_label = state.notification_status and notification_statusline_label(state.notification_status) or ""
	local notification_segment_label = notification_label ~= "" and (status_delimiter .. notification_label) or ""
	local model_label = status_delimiter .. current_model_statusline_label(ctx)
	local thinking_level = current_thinking_level_label(state)
	local thinking_label = thinking_level and (" [" .. thinking_level .. "]") or ""
	local spawn_label = spawn_statusline_label(state)
	local stats_label = " " .. format_session_stats(state) .. " "
	local statusline_win = tonumber(vim.g.statusline_winid) or ctx.state.transcript_win or 0
	local width = vim.api.nvim_win_get_width(statusline_win)
	local mode_width = vim.fn.strdisplaywidth(mode_label)
	local notification_width = vim.fn.strdisplaywidth(notification_segment_label)
	local model_width = vim.fn.strdisplaywidth(model_label)
	local thinking_width = vim.fn.strdisplaywidth(thinking_label)
	local spawn_width = vim.fn.strdisplaywidth(spawn_label)
	local left_width = mode_width + notification_width + model_width + thinking_width + spawn_width
	local stats_width = vim.fn.strdisplaywidth(stats_label)
	local show_stats = width >= (left_width + stats_width + 3)
	local mode_highlight = mode_statusline_highlight(mode)

	if width <= mode_width then
		local prefix_width = vim.fn.strdisplaywidth(mode_prefix)
		if width <= prefix_width then
			return "%#PiUsageStats#" .. statusline_escape(truncate_plain_to_width(mode_prefix, width)) .. "%*"
		end
		return "%#PiUsageStats#"
			.. statusline_escape(mode_prefix)
			.. mode_highlight
			.. statusline_escape(truncate_plain_to_width(mode_text .. mode_suffix, width - prefix_width))
			.. "%*"
	end

	local left_label = "%#PiUsageStats#"
		.. statusline_escape(mode_prefix)
		.. mode_highlight
		.. statusline_escape(mode_text)
		.. "%#PiUsageStats#"
		.. statusline_escape(mode_suffix)

	if width <= left_width then
		return left_label
			.. "%#PiUsageStats#"
			.. statusline_escape(truncate_plain_to_width(notification_segment_label .. model_label .. thinking_label .. spawn_label, width - mode_width))
			.. "%*"
	end

	if notification_label ~= "" then
		left_label = left_label
			.. statusline_escape(status_delimiter)
			.. notification_statusline_highlight(state.notification_status)
			.. statusline_escape(notification_label)
			.. "%#PiUsageStats#"
	end
	left_label = left_label .. statusline_escape(model_label)
	if thinking_label ~= "" then
		left_label = left_label
			.. thinking_statusline_highlight(thinking_level)
			.. statusline_escape(thinking_label)
			.. "%#PiUsageStats#"
	end
	if spawn_label ~= "" then
		left_label = left_label .. "%#PiUsageStats#" .. statusline_escape(spawn_label)
	end
	local right_label = show_stats and ("%#PiUsageStats#" .. statusline_escape(stats_label)) or ""
	return left_label .. "%#PiPaneBorder#%=" .. right_label .. "%*"
end

function M.setup(ctx)
	_G._pi_nvim_transcript_statusline = function()
		return M.render(ctx)
	end
end

function M.update(ctx)
	if not ctx.transcript.win_valid() then
		return
	end
	vim.api.nvim_set_option_value("statusline", "%!v:lua._pi_nvim_transcript_statusline()", { win = ctx.state.transcript_win })
	vim.cmd("redrawstatus!")
end

return M

local M = {}

function M.is_access_mode(ctx, mode)
	for _, candidate in ipairs(ctx.config.access_modes or {}) do
		if candidate == mode then
			return true
		end
	end
	return false
end

local function model_label(model)
	if type(model) ~= "table" then
		return tostring(model)
	end
	local provider = model.provider or model.providerName or model.providerId
	local id = model.modelId or model.id or model.name
	local display = model.displayName or model.label

	if display and provider and id then
		return string.format("%s (%s/%s)", display, provider, id)
	end
	if provider and id then
		return provider .. "/" .. id
	end
	return display or id or vim.inspect(model)
end

local function model_parts(model)
	local provider = model.provider or model.providerName or model.providerId
	local model_id = model.modelId or model.id or model.name

	if (not provider) and type(model_id) == "string" and model_id:find("/", 1, true) then
		provider, model_id = model_id:match("^([^/]+)/(.+)$")
	end

	return provider, model_id
end

function M.set_access_mode(ctx, mode)
	assert(M.is_access_mode(ctx, mode), "invalid access mode: " .. tostring(mode))
	ctx.state.access_mode = mode
	ctx.refresh_transcript_ui()
	if not (ctx.state.job and ctx.state.job > 0) then
		ctx.state.pending_access_mode = mode
		ctx.notify("Access mode will be applied when Pi starts: " .. mode)
		return
	end
	ctx.send({ type = "prompt", message = "/pi-mode " .. mode }, function(event)
		if not event.success then
			ctx.notify(event.error or "Could not set access mode", vim.log.levels.ERROR)
		end
	end)
end

function M.pick_access_mode(ctx)
	vim.ui.select(ctx.config.access_modes or {}, { prompt = "Pi access mode" }, function(choice)
		if not choice then
			return
		end
		M.set_access_mode(ctx, choice)
	end)
end

function M.cycle_access_mode(ctx)
	local modes = ctx.config.access_modes or {}
	if #modes == 0 then
		return
	end

	local current = 1
	for index, mode in ipairs(modes) do
		if mode == ctx.state.access_mode then
			current = index
			break
		end
	end

	local next_index = current + 1
	if next_index > #modes then
		next_index = 1
	end
	M.set_access_mode(ctx, modes[next_index])
end

function M.pick_thinking(ctx)
	local levels = { "off", "minimal", "low", "medium", "high", "xhigh" }
	vim.ui.select(levels, { prompt = "Thinking level" }, function(choice)
		if not choice then
			return
		end
		ctx.send({ type = "set_thinking_level", level = choice }, function(event)
			if event.success then
				ctx.state.thinking_level = choice
				ctx.refresh_transcript_ui()
				ctx.notify("Thinking: " .. choice)
			else
				ctx.notify("Could not set thinking level", vim.log.levels.ERROR)
			end
		end)
	end)
end

function M.pick_model(ctx)
	ctx.send({ type = "get_available_models" }, function(event)
		local models = event.data and event.data.models or {}
		if #models == 0 then
			ctx.notify("No models returned by Pi", vim.log.levels.WARN)
			return
		end

		vim.ui.select(models, {
			prompt = "Pi model",
			format_item = model_label,
		}, function(choice)
			if not choice then
				return
			end
			local provider, model_id = model_parts(choice)
			if not provider or not model_id then
				ctx.notify("Could not infer provider/modelId from selected model", vim.log.levels.ERROR)
				return
			end
			ctx.send({ type = "set_model", provider = provider, modelId = model_id }, function(set_event)
				if set_event.success then
					ctx.config.provider = provider
					ctx.config.model = model_id
					ctx.set_model_metadata(provider, model_id)
					ctx.refresh_transcript_ui()
					ctx.notify("Model: " .. model_label(choice))
				else
					ctx.notify("Could not set model", vim.log.levels.ERROR)
				end
			end)
		end)
	end)
end

local function command_label(command)
	local prefix = "/" .. tostring(command.name or "")
	local source = command.source and (" [" .. command.source .. "]") or ""
	local description = command.description and command.description ~= "" and (" — " .. command.description) or ""
	return prefix .. source .. description
end

function M.pick_command(ctx)
	ctx.send({ type = "get_commands" }, function(event)
		local commands = event.data and event.data.commands or {}
		if #commands == 0 then
			ctx.notify("No Pi commands returned", vim.log.levels.WARN)
			return
		end
		table.sort(commands, function(a, b)
			return tostring(a.name or "") < tostring(b.name or "")
		end)
		vim.ui.select(commands, {
			prompt = "Pi command",
			format_item = command_label,
		}, function(choice)
			if not choice or not choice.name then
				return
			end
			ctx.set_input_text("/" .. tostring(choice.name) .. " ")
		end)
	end)
end

function M.reload(ctx)
	ctx.send({ type = "prompt", message = "/reload" }, function(event)
		if event.success then
			ctx.notify("Pi reload requested")
		else
			ctx.notify(event.error or "Could not reload Pi", vim.log.levels.ERROR)
		end
	end)
end

return M

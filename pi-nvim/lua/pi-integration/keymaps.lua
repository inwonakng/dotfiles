local M = {}

M.specs = {
	input = {
		{ modes = { "n", "i" }, lhs = "<C-CR>", action = "submit_prompt", desc = "Submit prompt" },
	},
	shared = {
		{ lhs = "<Tab>", action = "cycle_access_mode", desc = "Cycle access mode" },
		{ lhs = "<leader>?", action = "show_help", desc = "Pi help" },
		{ lhs = "<leader>/", action = "pick_command", desc = "Pick Pi command" },
		{ lhs = "<leader>pi", action = "show_input", desc = "Show Pi input" },
		{ lhs = "<leader>pr", action = "reload", desc = "Reload Pi resources" },
		{ lhs = "<leader>pt", action = "show_transcript", desc = "Show Pi transcript" },
		{ lhs = "<leader>ps", action = "pick_spawn", desc = "Show subagents" },
		{ lhs = "<leader>a", action = "pick_access_mode", desc = "Pick access mode" },
		{ lhs = "<leader>m", action = "pick_model", desc = "Pick model" },
		{ lhs = "<leader>t", action = "pick_thinking", desc = "Pick thinking level" },
		{ lhs = "<leader>s", action = "pick_session", desc = "Pick session" },
		{ lhs = "<leader>h", action = "history", desc = "History" },
		{ lhs = "<leader>T", action = "show_tree", desc = "Session tree" },
		{ lhs = "<leader>N", action = "new_session", desc = "New session" },
		{ lhs = "<leader>n", action = "toggle_notifications", desc = "Toggle notifications" },
		{ lhs = "<leader>r", action = "refresh_messages", desc = "Refresh transcript" },
		{ lhs = "<leader>R", action = "rename_session", desc = "Rename session" },
	},
	transcript = {
		{ lhs = "<Esc><Esc>", action = "abort", desc = "Abort Pi" },
		{
			lhs = "<CR>",
			action = "open_transcript_item",
			desc = "Open tool/thinking/skill output",
		},
	},
}

local function action_fn(ctx, action)
	if action == "open_transcript_item" then
		return function()
			ctx.transcript.open_item_under_cursor()
		end
	end

	return function()
		local fn = ctx.actions[action]
		if type(fn) == "function" then
			fn()
		else
			ctx.ui.notify("Missing Pi action: " .. tostring(action), vim.log.levels.ERROR)
		end
	end
end

local function set_keymaps(ctx, buf, specs)
	if not ctx.buffer.valid(buf) then
		return
	end
	for _, spec in ipairs(specs) do
		vim.keymap.set(spec.modes or "n", spec.lhs, action_fn(ctx, spec.action), {
			buffer = buf,
			desc = spec.desc,
		})
	end
end

local function which_key_specs(buf, specs)
	local result = {}
	for _, spec in ipairs(specs) do
		local item = {
			spec.lhs,
			buffer = buf,
			desc = spec.desc,
		}
		if spec.modes then
			item.mode = spec.modes
		end
		table.insert(result, item)
	end
	return result
end

local function register_which_key(ctx, buf, specs)
	if not ctx.buffer.valid(buf) then
		return
	end
	local ok, which_key = pcall(require, "which-key")
	if not ok then
		return
	end
	which_key.add(which_key_specs(buf, specs))
end

function M.merged(context)
	local specs = vim.deepcopy(M.specs.shared)
	vim.list_extend(specs, vim.deepcopy(M.specs[context] or {}))
	return specs
end

function M.setup(ctx)
	local input_specs = M.merged("input")
	local transcript_specs = M.merged("transcript")

	set_keymaps(ctx, ctx.state.input_buf, input_specs)
	set_keymaps(ctx, ctx.state.transcript_buf, transcript_specs)
	register_which_key(ctx, ctx.state.input_buf, input_specs)
	register_which_key(ctx, ctx.state.transcript_buf, transcript_specs)
end

function M.help_key_lines()
	local lines = {
		"- `<C-CR>` submit the input buffer.",
	}
	for _, spec in ipairs(M.specs.shared) do
		table.insert(lines, "- `" .. spec.lhs .. "` " .. spec.desc .. ".")
	end
	vim.list_extend(lines, {
		"- `<CR>` open the current tool/thinking/skill output.",
		"- `<Esc><Esc>` abort Pi.",
		"- `q` or `<Esc>` close this help.",
	})
	return lines
end

return M

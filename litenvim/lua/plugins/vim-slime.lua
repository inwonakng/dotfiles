-- Tmux pane picker for vim-slime
vim.api.nvim_create_user_command("SlimePickPane", function()
	local fzf = require("fzf-lua")
	local nvim_cwd = vim.fn.getcwd()

	-- Check if a pixi process is running ipython
	local function is_pixi_ipython(pid)
		if not pid or pid == "" then
			return false
		end
		local h = io.popen(string.format("ps -o args= -p %s 2>/dev/null", pid))
		if not h then
			return false
		end
		local cmd = h:read("*l") or ""
		h:close()
		return cmd:lower():find("ipython") ~= nil
	end

	-- Get all tmux panes with relevant info
	local handle = io.popen(
		[[tmux list-panes -a -F "#{pane_id}|#{pane_current_path}|#{pane_current_command}|#{window_name}|#{session_name}|#{pane_pid}"]]
	)
	if not handle then
		vim.notify("Failed to get tmux panes", vim.log.levels.ERROR)
		return
	end
	local result = handle:read("*a")
	handle:close()

	local panes = {}
	local repl_cmds = { python = true, python3 = true, ipython = true, ipython3 = true }
	for line in result:gmatch("[^\n]+") do
		local pane_id, pane_path, pane_cmd, window_name, session_name, pane_pid =
			line:match("([^|]+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
		if pane_id then
			local cmd_lower = (pane_cmd or ""):lower()
			local is_repl = repl_cmds[cmd_lower] or (cmd_lower == "pixi" and is_pixi_ipython(pane_pid))
			table.insert(panes, {
				id = pane_id,
				path = pane_path or "",
				cmd = pane_cmd or "",
				is_repl = is_repl,
				window = window_name or "",
				session = session_name or "",
			})
		end
	end

	-- Sort panes by priority
	table.sort(panes, function(a, b)
		-- Priority 1: Same cwd as nvim
		local a_same_cwd = a.path == nvim_cwd
		local b_same_cwd = b.path == nvim_cwd
		if a_same_cwd ~= b_same_cwd then
			return a_same_cwd
		end

		-- Priority 2: Running a REPL (python/ipython/pixi+ipython)
		if a.is_repl ~= b.is_repl then
			return a.is_repl
		end

		-- Priority 3: By pane ID (lower = older/more stable)
		return a.id < b.id
	end)

	-- Format entries for fzf
	local entries = {}
	for _, pane in ipairs(panes) do
		local display = string.format(
			"%s  [%s]  %s:%s  %s",
			pane.id,
			pane.cmd ~= "" and pane.cmd or "-",
			pane.session,
			pane.window,
			pane.path
		)
		table.insert(entries, display)
	end

	if #entries == 0 then
		vim.notify("No tmux panes found", vim.log.levels.WARN)
		return
	end

	fzf.fzf_exec(entries, {
		prompt = "Slime Target> ",
		winopts = {
			height = 0.4,
			width = 1.0,
			row = 1.0,
		},
		actions = {
			["default"] = function(selected)
				if selected and #selected > 0 then
					local pane_id = selected[1]:match("^(%%[^%s]+)")
					if pane_id then
						vim.g.slime_default_config = { socket_name = "default", target_pane = pane_id }
						vim.b.slime_config = { socket_name = "default", target_pane = pane_id }
						vim.notify("Slime target set to: " .. pane_id)
					end
				end
			end,
		},
	})
end, { desc = "Pick a tmux pane for vim-slime" })

return {
	-- slime (REPL integration)
	{
		"jpalardy/vim-slime",
		keys = {
			{ "<leader>r", "", desc = "+vim-slime" },
			{ "<leader>rc", "<CMD>SlimeConfig<CR>", desc = "Slime Config" },
			{ "<leader>rp", "<CMD>SlimePickPane<CR>", desc = "Pick Tmux Pane" },
			{ "<leader>rr", "<Plug>SlimeSendCell", desc = "Slime Send Cell" },
			{ "<leader>rr", ":<C-u>'<,'>SlimeSend<CR>", mode = "v", desc = "Slime Send Selection" },
			{ "<leader>rn", "o# %%<ESC>o<ESC>D", desc = "Sime Insert New Cell" },
			{ "]r", "/# %%<CR>", desc = "Sime Next Cell" },
			{ "[r", "k/# %%<CR>N", desc = "Sime Previous Cell" },
			{
				"<leader>rf",
				function()
					_G.SlimeFolds.create_slime_cell_folds()
				end,
				desc = "Create folds for slime cells (open)",
			},
			{
				"<leader>rF",
				function()
					_G.SlimeFolds.create_and_close_slime_cell_folds()
				end,
				desc = "Create folds for slime cells (closed)",
			},
		},
		config = function()
			vim.g.slime_no_mappings = 1
			-- vim.g.slime_target = "wezterm"
			vim.g.slime_target = "tmux"
			vim.g.slime_cell_delimiter = "# %%"
			vim.g.slime_bracketed_paste = 1
			vim.g.slime_python_ipython = 0

			-- Function to create folds for vim-slime cells (between # %% markers)
			local function create_slime_cell_folds()
				local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
				local cell_starts = {}

				-- Find all cell delimiter lines
				for i, line in ipairs(lines) do
					if line:match("^%s*#%s*%%%%") then
						table.insert(cell_starts, i)
					end
				end

				-- Helper function to find first non-comment line after a given line
				local function find_first_non_comment(start_idx, end_idx)
					local in_multiline_comment = false
					local multiline_delimiter = nil

					for i = start_idx, end_idx do
						local line = lines[i]:gsub("^%s*", "") -- Remove leading whitespace
						local skip_line = false

						-- Skip empty lines
						if line == "" then
							skip_line = true
						elseif not in_multiline_comment then
							-- Handle multiline comment start
							if line:match('^"""') or line:match("^'''") then
								multiline_delimiter = line:match('^(""")') or line:match("^(''')")
								-- Check if it's a single-line multiline comment
								if line:match(multiline_delimiter .. ".-" .. multiline_delimiter) then
									skip_line = true -- Single-line multiline comment, skip
								else
									in_multiline_comment = true
									skip_line = true
								end
							end
						end

						-- Handle multiline comment end
						if in_multiline_comment and not skip_line then
							if line:find(multiline_delimiter) then
								in_multiline_comment = false
								multiline_delimiter = nil
							end
							skip_line = true
						end

						-- Skip single-line comments (but not cell delimiters)
						if not skip_line and line:match("^#") and not line:match("^#%s*%%%%") then
							skip_line = true
						end

						-- Found first non-comment line
						if not skip_line then
							return i
						end
					end

					return end_idx + 1 -- No non-comment line found
				end

				-- Create folds between cell delimiters
				for i = 1, #cell_starts - 1 do
					local after_delimiter = cell_starts[i] + 1
					local end_line = cell_starts[i + 1] - 1
					local start_line = find_first_non_comment(after_delimiter, end_line)

					-- Only create fold if there's content between delimiters
					if start_line <= end_line then
						vim.cmd(start_line .. "," .. end_line .. "fold")
						vim.cmd(start_line .. "," .. end_line .. "foldopen")
					end
				end

				-- Handle the last cell (from last delimiter to end of file)
				if #cell_starts > 0 then
					local after_delimiter = cell_starts[#cell_starts] + 1
					local end_line = #lines
					local start_line = find_first_non_comment(after_delimiter, end_line)

					if start_line <= end_line then
						vim.cmd(start_line .. "," .. end_line .. "fold")
						vim.cmd(start_line .. "," .. end_line .. "foldopen")
					end
				end
			end

			-- Function to create folds for vim-slime cells and close them
			local function create_and_close_slime_cell_folds()
				local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
				local cell_starts = {}

				-- Find all cell delimiter lines
				for i, line in ipairs(lines) do
					if line:match("^%s*#%s*%%%%") then
						table.insert(cell_starts, i)
					end
				end

				-- Helper function to find first non-comment line after a given line
				local function find_first_non_comment(start_idx, end_idx)
					local in_multiline_comment = false
					local multiline_delimiter = nil

					for i = start_idx, end_idx do
						local line = lines[i]:gsub("^%s*", "") -- Remove leading whitespace
						local skip_line = false

						-- Skip empty lines
						if line == "" then
							skip_line = true
						elseif not in_multiline_comment then
							-- Handle multiline comment start
							if line:match('^"""') or line:match("^'''") then
								multiline_delimiter = line:match('^(""")') or line:match("^(''')")
								-- Check if it's a single-line multiline comment
								if line:match(multiline_delimiter .. ".-" .. multiline_delimiter) then
									skip_line = true -- Single-line multiline comment, skip
								else
									in_multiline_comment = true
									skip_line = true
								end
							end
						end

						-- Handle multiline comment end
						if in_multiline_comment and not skip_line then
							if line:find(multiline_delimiter) then
								in_multiline_comment = false
								multiline_delimiter = nil
							end
							skip_line = true
						end

						-- Skip single-line comments (but not cell delimiters)
						if not skip_line and line:match("^#") and not line:match("^#%s*%%%%") then
							skip_line = true
						end

						-- Found first non-comment line
						if not skip_line then
							return i
						end
					end

					return end_idx + 1 -- No non-comment line found
				end

				-- Create folds between cell delimiters
				for i = 1, #cell_starts - 1 do
					local after_delimiter = cell_starts[i] + 1
					local end_line = cell_starts[i + 1] - 1
					local start_line = find_first_non_comment(after_delimiter, end_line)

					-- Only create fold if there's content between delimiters
					if start_line <= end_line then
						vim.cmd(start_line .. "," .. end_line .. "fold")
					end
				end

				-- Handle the last cell (from last delimiter to end of file)
				if #cell_starts > 0 then
					local after_delimiter = cell_starts[#cell_starts] + 1
					local end_line = #lines
					local start_line = find_first_non_comment(after_delimiter, end_line)

					if start_line <= end_line then
						vim.cmd(start_line .. "," .. end_line .. "fold")
					end
				end
			end

			-- Export functions for use in keymaps
			_G.SlimeFolds = {
				create_slime_cell_folds = create_slime_cell_folds,
				create_and_close_slime_cell_folds = create_and_close_slime_cell_folds,
			}
		end,
	},
}

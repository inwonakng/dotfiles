local get_recent_daily_note_content = function()
	local most_recent_content = ""
	local files = vim.split(vim.fn.glob("daily/*.md"), "\n")
	if #files > 0 then
		files = vim.fn.sort(files)
		-- by the time this is called, the current daily note is already
		-- created by the ObsidianToday command. so we want to get the
		-- second most recent.
		local most_recent = files[#files - 1]
		local file = io.open(most_recent, "r")
		if not file then
			vim.notify("Error: Could not open template file: " .. most_recent, vim.log.levels.ERROR)
			return
		end
		most_recent_content = file:read("*a") -- Read the whole file
		local past_frontmatter_open = false
		local past_frontmatter_close = false
		local without_frontmatter_lines = {}
		local lines = vim.split(most_recent_content, "\n")
		for i = 1, #lines do
			if past_frontmatter_open and past_frontmatter_close then
				table.insert(without_frontmatter_lines, lines[i])
			elseif lines[i]:match("^---$") then
				if not past_frontmatter_open then
					past_frontmatter_open = true -- we have reached the end of the frontmatter
				elseif not past_frontmatter_close then
					past_frontmatter_close = true -- we have reached the end of the frontmatter
				end
			end
		end
		-- remove the template lines from the most recent content
		file:close()
		most_recent_content = table.concat(without_frontmatter_lines, "\n")
	end
	return most_recent_content
end

return {
	"obsidian-nvim/obsidian.nvim",
	version = "*", -- recommended, use latest release instead of latest commit
	lazy = true,
	ft = "markdown",
	-- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
	-- event = {
	--   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
	--   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
	--   -- refer to `:h file-pattern` for more examples
	--   "BufReadPre path/to/my-vault/*.md",
	--   "BufNewFile path/to/my-vault/*.md",
	-- },
	dependencies = {
		-- Required.
		"nvim-lua/plenary.nvim",
		-- see above for full list of optional dependencies ☝️
	},
	keys = {
		{ "<leader>ot", "<cmd>ObsidianTemplate<cr>", desc = "Insert template" },
		{ "<leader>oT", "<cmd>ObsidianTemplate default.md<cr>", desc = "Insert default template" },
		{ "<leader>od", "<cmd>ObsidianToday<cr>", desc = "Create a daily note" },
		{ "<leader>oo", "<cmd>ObsidianOpen<cr>", desc = "Open in Obsidian" },
		{ "<C-CR>", "<cmd>ObsidianFollowLink vsp<cr>", desc = "Follow link in vsplit" },
		{ "<S-CR>", "<cmd>ObsidianFollowLink hsplit<cr>", desc = "Follow link in hsplit" },
		{ "<leader>oD", "<cmd>ObsidianDailies<cr>", desc = "Follow link" },
	},
	---@module 'obsidian'
	---@type obsidian.config.ClientOpts
	opts = {
		workspaces = {
			{
				name = "personal",
				path = "/Users/inwon/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal",
			},
			{
				name = "work",
				path = "/Users/inwon/Library/Mobile Documents/iCloud~md~obsidian/Documents/work",
			},
		},
		daily_notes = {
			folder = "daily",
			date_format = "%Y-%m-%d",
			default_tags = {},
			template = "daily",
		},
		completion = {
			blink = true,
			min_chars = 2,
		},
		preferred_link_style = "markdown",
		-- Optional, for templates (see https://github.com/obsidian-nvim/obsidian.nvim/wiki/Using-templates)
		note_frontmatter_func = function(note)
			-- sort the tags
			local is_paper_reading = false
			local sorted_tags = {}
			for i = 1, #note.tags do
				if note.tags[i] == "paper-summary" then
					is_paper_reading = true
				elseif note.tags[i]:match("^%s*$") then
				-- skip empty tags
				else
					table.insert(sorted_tags, note.tags[i])
				end
			end

			sorted_tags = vim.fn.sort(sorted_tags, function(a, b)
				return a:lower() > b:lower()
			end)

			if is_paper_reading then
				table.insert(sorted_tags, 1, "paper-summary")
			end

			local out = { tags = sorted_tags, title = "", summary = "", aliases = note.aliases or {} }
			-- `note.metadata` contains any manually added fields in the frontmatter.
			-- So here we just make sure those fields are kept in the frontmatter.
			if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
				for k, v in pairs(note.metadata) do
					out[k] = v
				end
			end
			return out
		end,
		templates = {
			folder = "templates",
			date_format = "%Y-%m-%d",
			time_format = "%H:%M",
			-- A map for custom variables, the key should be the variable and the value a function
			substitutions = {
				most_recent_daily_note = get_recent_daily_note_content,
			},
		},
		picker = {
			name = "fzf-lua",
			note_mappings = {
				-- Create a new note from your query.
				new = "<C-x>",
				-- Insert a link to the selected note.
				insert_link = "<C-l>",
			},
			tag_mappings = {
				-- Add tag(s) to current note.
				tag_note = "<C-x>",
				-- Insert a tag at the current location.
				insert_tag = "<C-l>",
			},
		},
		ui = {
			enable = false,
			checkboxes = {
				[" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
				["x"] = { char = "", hl_group = "ObsidianDone" },
			},
		},
	},
}

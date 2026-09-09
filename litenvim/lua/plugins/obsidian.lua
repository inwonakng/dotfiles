vim.pack.add({ "https://github.com/obsidian-nvim/obsidian.nvim" })

require("obsidian").setup({
	legacy_commands = false,
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
	},
	completion = {
		-- blink = true,
		min_chars = 2,
	},
	link = {
		style = "markdown",
	},
	-- Optional, for templates (see https://github.com/obsidian-nvim/obsidian.nvim/wiki/Using-templates)
	frontmatter = {
		enabled = function(path)
			return vim.fn.fnamemodify(path, ":t") ~= "AGENTS.md"
		end,
		sort = { "title", "summary", "date", "tags", "aliases" },
		func = function(note)
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

			local out = { tags = sorted_tags, title = "", date = "", summary = "", aliases = note.aliases or {} }
			-- `note.metadata` contains any manually added fields in the frontmatter.
			-- So here we just make sure those fields are kept in the frontmatter.
			if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
				for k, v in pairs(note.metadata) do
					out[k] = v
				end
			end
			return out
		end,
	},
	footer = {
		enabled = false,
	},
	templates = {
		folder = "templates",
		date_format = "%Y-%m-%d",
		time_format = "%H:%M",
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
	},
	checkbox = {
		order = { " ", "x" },
	},
})

-- Only regular templates belong in Neovim's insertion picker. Obsidian owns
-- daily/default rendering; ordinary Neovim notes get frontmatter on save.
local function insert_regular_template()
	local dir = require("obsidian.api").templates_dir()
	if not dir then
		return
	end
	local templates = {}
	for _, path in ipairs(vim.fn.globpath(tostring(dir), "**/*.md", false, true)) do
		local name = path:sub(#tostring(dir) + 2)
		if name ~= "daily.md" and name ~= "default.md" then
			table.insert(templates, name)
		end
	end
	table.sort(templates)
	require("obsidian.picker").select(templates, {
		prompt = "Insert template",
		no_default_mappings = true,
	}, function(choices)
		if choices and choices[1] then
			require("obsidian.actions").insert_template(choices[1])
		end
	end)
end

local function open_daily_note()
	local workspace = require("obsidian.api").find_workspace(vim.api.nvim_buf_get_name(0)) or Obsidian.workspace
	-- Use the application launcher, not its internal obsidian-cli binary:
	-- the launcher routes commands to the requested vault.
	local cli = vim.fn.exepath("obsidian")
	if cli == "" then
		cli = "/Applications/Obsidian.app/Contents/MacOS/Obsidian"
	end
	if vim.fn.executable(cli) ~= 1 then
		vim.notify("Enable the Obsidian CLI before creating daily notes", vim.log.levels.ERROR)
		return
	end
	local function run(command, ...)
		local result = vim.system({ cli, "vault=" .. workspace.name, command, ... }, { text = true }):wait(10000)
		local output = vim.trim(result.stdout or "")
		if result.code ~= 0 or output:match("^Error:") then
			error(
				("Obsidian CLI %s failed (exit %s): %s"):format(
					command,
					result.code,
					vim.trim((result.stderr or "") .. "\n" .. output)
				)
			)
		end
		return output
	end
	local ok, err = pcall(function()
		local relative = run("daily:path")
		if relative == "" or relative:find("[\r\n]") or not relative:match("%.md$") then
			error("Obsidian did not return a daily note path")
		end
		local path = vim.fs.joinpath(tostring(workspace.root), relative)
		if vim.fn.filereadable(path) ~= 1 then
			-- The app action opens Source mode, where Templater's editor changes
			-- are saved correctly. CLI `daily` instead uses the default view mode.
			run("command", "id=daily-notes")
			-- The creation hook runs asynchronously after the empty file is made.
			if not vim.wait(10000, function()
				return vim.fn.getfsize(path) > 0
			end, 100) then
				error("Daily note remained empty; check Templater in Obsidian: " .. relative)
			end
		end
		vim.cmd.edit(vim.fn.fnameescape(path))
	end)
	if not ok then
		vim.notify(tostring(err), vim.log.levels.ERROR)
	end
end

vim.keymap.set("n", "<leader>ot", insert_regular_template, { desc = "Insert regular template" })
vim.keymap.set("n", "<leader>od", open_daily_note, { desc = "Open daily note through Obsidian" })
vim.keymap.set("n", "<leader>oo", "<cmd>Obsidian open<cr>", { desc = "Open in Obsidian" })
vim.keymap.set("n", "<C-CR>", "<cmd>Obsidian follow_link vsp<cr>", { desc = "Follow link in vsplit" })
vim.keymap.set("n", "<S-CR>", "<cmd>Obsidian follow_link hsplit<cr>", { desc = "Follow link in hsplit" })
vim.keymap.set("n", "<leader>oD", "<cmd>Obsidian dailies<cr>", { desc = "Pick from daily notes" })

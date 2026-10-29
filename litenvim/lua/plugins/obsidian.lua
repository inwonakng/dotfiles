local obsidian = require("utils.obsidian")
local workspaces = obsidian.workspaces()

if vim.tbl_isempty(workspaces) then
	return
end

vim.pack.add({ "https://github.com/obsidian-nvim/obsidian.nvim" })

require("obsidian").setup({
	legacy_commands = false,
	workspaces = workspaces,
	open = vim.fn.has("wsl") == 1 and { func = obsidian.open } or nil,
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
local function insert_regular_template(workspace)
	local dir = require("obsidian.api").templates_dir(workspace)
	if not dir then
		return
	end
	local templates = {}
	for _, path in ipairs(vim.fn.globpath(tostring(dir), "**/*.md", false, true)) do
		local name = path:sub(#tostring(dir) + 2)
		if name ~= "daily.md" and name ~= "default.md" and name ~= "project-notes.md" and name ~= "project-daily.md" then
			table.insert(templates, name)
		end
	end
	table.sort(templates)
	require("obsidian.picker").select(templates, {
		prompt = "Insert template",
		no_default_mappings = true,
	}, function(choices)
		if choices and choices[1] then
			require("obsidian.actions").insert_template(vim.fs.joinpath(tostring(dir), choices[1]))
		end
	end)
end

local function open_daily_note(workspace)
	local function run(command, ...)
		local result = vim.system({ obsidian.cli(), "vault=" .. workspace.name, command, ... }, { text = true }):wait(10000)
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
		obsidian.cli()
		obsidian.launch(workspace)
		local relative, last_error
		if not vim.wait(30000, function()
			local ready, output = pcall(run, "daily:path")
			if ready and output ~= "" and not output:find("[\r\n]") and output:match("%.md$") then
				relative = output
				return true
			end
			last_error = ready and "Obsidian did not return a daily note path" or output
			return false
		end, 250) then
			error("Obsidian did not become ready: " .. tostring(last_error))
		end
		local path = vim.fs.joinpath(workspace.path, relative)
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
		local buffer = vim.fn.bufnr(path)
		local windows = buffer ~= -1 and vim.fn.win_findbuf(buffer) or {}
		if windows[1] then
			vim.api.nvim_set_current_win(windows[1])
		else
			vim.cmd.edit(vim.fn.fnameescape(path))
		end
	end)
	if not ok then
		vim.notify(tostring(err), vim.log.levels.ERROR)
	end
end

vim.api.nvim_create_user_command("ProjectNotesInit", function()
	require("utils.project-notes").initialize(workspaces)
end, { desc = "Initialize project notes in an Obsidian vault" })
vim.keymap.set("n", "<leader>oN", "<cmd>ProjectNotesInit<cr>", { desc = "Initialize project notes" })
vim.api.nvim_create_user_command("ProjectDailies", function()
	local path = vim.api.nvim_buf_get_name(0)
	local current = path ~= "" and require("obsidian.api").find_workspace(path) or nil
	if not current or vim.bo.buftype ~= "" then
		vim.notify("Project dailies are only available inside an Obsidian vault", vim.log.levels.WARN)
		return
	end
	require("utils.project-notes").pick({ name = current.name, path = tostring(current.root) })
end, { desc = "Pick a project to open today's daily" })
local function update_vault_mappings(buffer)
	local path = vim.api.nvim_buf_get_name(buffer)
	local workspace = path ~= "" and require("obsidian.api").find_workspace(path) or nil
	if workspace and vim.bo[buffer].buftype == "" then
		vim.keymap.set("n", "<leader>ot", function()
			insert_regular_template(workspace)
		end, { buffer = buffer, desc = "Insert template" })
		vim.keymap.set("n", "<leader>oD", "<cmd>ProjectDailies<cr>", { buffer = buffer, desc = "Pick project daily" })
		vim.b[buffer].vault_mappings = true
	elseif vim.b[buffer].vault_mappings then
		vim.keymap.del("n", "<leader>ot", { buffer = buffer })
		vim.keymap.del("n", "<leader>oD", { buffer = buffer })
		vim.b[buffer].vault_mappings = nil
	end
end
vim.api.nvim_create_autocmd({ "BufEnter", "BufFilePost" }, {
	group = vim.api.nvim_create_augroup("vault_mappings", { clear = true }),
	callback = function(event)
		update_vault_mappings(event.buf)
	end,
})
update_vault_mappings(vim.api.nvim_get_current_buf())
vim.keymap.set("n", "<leader>od", function()
	if not vim.g.project_mode then
		return
	end
	local directory = vim.uv.fs_realpath(vim.fn.getcwd())
	for _, workspace in ipairs(workspaces) do
		local root = vim.uv.fs_realpath(workspace.path)
		if directory and root and (directory == root or directory:sub(1, #root + 1) == root .. "/") then
			open_daily_note(workspace)
			return
		end
	end
	if not require("utils.project-notes").open(workspaces) then
		vim.notify("no project notes, first link an obsidian project note directory", vim.log.levels.WARN)
	end
end, { desc = "Open daily note" })
vim.keymap.set("n", "<leader>oo", "<cmd>Obsidian open<cr>", { desc = "Open in Obsidian" })
vim.keymap.set("n", "<C-CR>", "<cmd>Obsidian follow_link vsp<cr>", { desc = "Follow link in vsplit" })
vim.keymap.set("n", "<S-CR>", "<cmd>Obsidian follow_link hsplit<cr>", { desc = "Follow link in hsplit" })

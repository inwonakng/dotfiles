local M = {}

function M.insert_file_content_from_dir(opts)
	opts = opts or {}
	local search_dir = opts.dir
	local prompt = opts.prompt or "Insert from: "

	if not search_dir or vim.fn.isdirectory(search_dir) == 0 then
		vim.notify(
			"Error: Directory '" .. tostring(search_dir) .. "' does not exist or is not a directory.",
			vim.log.levels.ERROR
		)
		return
	end

	-- Ensure the directory path ends with a separator for fzf's `cwd`
	if not search_dir:match("[/\\]$") then
		search_dir = search_dir .. (vim.fn.has("win32") == 1 and "\\" or "/")
	end

	require("fzf-lua").files({
		prompt = opts.prompt,
		cwd = search_dir, -- Crucial: scope the search to this directory
		path_shorten = 1,
		actions = {
			-- The 'default' action is triggered by <CR> (Enter)
			["default"] = function(selected)
				if not selected or #selected == 0 then
					vim.notify("No file selected.", vim.log.levels.INFO)
					return
				end

				local filepath = require("fzf-lua.path").entry_to_file(selected[1]).path
				local full_filepath = vim.fn.fnamemodify(search_dir .. filepath, ":p")

				local file = io.open(full_filepath, "r")
				if not file then
					vim.notify("Error: Could not open file: " .. full_filepath, vim.log.levels.ERROR)
					return
				end

				local content = file:read("*a") -- Read the whole file
				file:close()

				-- before we insert, handle any placeholders to replace
				content = content:gsub("{{date}}", os.date("%Y-%m-%d"))

				vim.notify("Read content from: " .. full_filepath, vim.log.levels.DEBUG)
				if content then
					-- Split content into lines for nvim_put
					local lines = vim.split(content, "\n", { plain = true })
					vim.notify("this is lines: " .. vim.inspect(lines), vim.log.levels.DEBUG)

					-- vim.api.nvim_put takes a table of lines, type of paste, and placement
					-- 'c' for character-wise (inserts at cursor)
					-- true for 'after' cursor
					-- true for 'fixend' (adjust cursor position)
					vim.api.nvim_put(lines, "c", true, true)
					vim.notify("Inserted content from: " .. filepath, vim.log.levels.INFO)
				else
					vim.notify("File is empty: " .. filepath, vim.log.levels.WARN)
				end
			end,
			-- You can add other actions, e.g., open the file instead of inserting
			["ctrl-x"] = function(selected)
				if not selected or #selected == 0 then
					return
				end
				local full_filepath = vim.fn.fnamemodify(search_dir .. selected[1], ":p")
				vim.cmd("edit " .. vim.fn.fnameescape(full_filepath))
			end,
		},
		-- You can add fzf_opts or find_opts here if needed
		-- fzf_opts = { ['--info'] = 'inline' },
		-- find_opts = [[--type f --hidden --exclude .git --exclude node_modules]], -- example for fd
	})
end

function M.create_daily_note(opts)
	local daily_note_dir = opts and opts.dir or vim.fn.expand("daily")
	local template_file = opts and opts.template or vim.fn.expand("templates/default.md")

	if not daily_note_dir:match("[/\\]$") then
		daily_note_dir = daily_note_dir .. (vim.fn.has("win32") == 1 and "\\" or "/")
	end

	local filepath = daily_note_dir .. os.date("%Y-%m-%d") .. ".md"

	-- if the current file is already opened, do nothing
	if vim.fn.expand("%:p") == filepath then
		return
	end
	-- if it already exists, just open it
	if vim.fn.filereadable(filepath) == 1 then
		vim.cmd("edit " .. vim.fn.fnameescape(filepath))
		return
	end

	-- otherwise, create the file and open it.
	local file = io.open(template_file, "r")
	if not file then
		vim.notify("Error: Could not open template file: " .. template_file, vim.log.levels.ERROR)
		return
	end
	local template_content = file:read("*a") -- Read the whole file
	file:close()

	-- before we insert, handle any placeholders to replace
	template_content = template_content:gsub("{{date}}", os.date("%Y-%m-%d"))
	local template_lines = vim.split(template_content, "\n")

  local most_recent_content = ""
	local files = vim.fn.sort(vim.split(vim.fn.glob(daily_note_dir .. "*.md"), "\n"))
	if #files > 0 then
		local most_recent = files[#files]
		local file = io.open(most_recent, "r")
		if not file then
			vim.notify("Error: Could not open template file: " .. most_recent, vim.log.levels.ERROR)
			return
		end
		most_recent_content = file:read("*a") -- Read the whole file
		local lines = vim.split(most_recent_content, "\n")
    -- remove the template lines from the most recent content
    local without_template_lines = {}
    for i = #template_lines, #lines do
      table.insert(without_template_lines, lines[i])
    end
		file:close()
    most_recent_content = table.concat(without_template_lines, "\n")
	end

	local file = io.open(filepath, "w")
	if not file then
		vim.notify("Error: Could not create daily note at: " .. filepath, vim.log.levels.ERROR)
		return
	end

  if most_recent_content == nil then
    return
  end

	file:write(template_content)
  file:write("\n## Today\n\n\n---\n\n## Previous\n\n")
	file:write(most_recent_content)
	file:close()
	vim.cmd("edit " .. vim.fn.fnameescape(filepath))
end

return M

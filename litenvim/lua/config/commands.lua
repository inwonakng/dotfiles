vim.api.nvim_create_user_command("FindTag", function(opts)
	if not vim.tbl_contains({
		"NOTE",
		"TODO",
		"FIXME",
		"DEBUG",
	}, opts.args) then
		return
	end
	require("fzf-lua").grep({
		search = string.format([[%s:|%s!\(.*\)]], opts.args, string.lower(opts.args)),
		no_esc = true,
	})
end, {
	desc = "List fixmes",
	nargs = "?",
	complete = function()
		return {
			"NOTE",
			"TODO",
			"FIXME",
			"DEBUG",
		}
	end,
})

vim.api.nvim_create_user_command("YankFilePath", function()
	-- Get the full path of the current buffer
	local file_path = vim.fn.expand("%:p")
	-- Yank the file path to the system clipboard
	vim.fn.setreg("+", file_path)
	-- Optional: Print a message to confirm the action
	print("File path yanked: " .. file_path)
end, {})

vim.api.nvim_create_user_command("YankRelativeFilePath", function()
	-- Get the full path of the current buffer
	local full_path = vim.fn.expand("%:p")
	-- Get the current working directory
	local cwd = vim.fn.getcwd()
	-- Get the relative path
	local relative_path = vim.fn.fnamemodify(full_path, ":." .. cwd .. ":~:.")
	-- Yank the relative path to the system clipboard
	vim.fn.setreg("+", relative_path)
	-- Print a message to confirm the action
	print("Relative file path yanked: " .. relative_path)
end, {})

vim.api.nvim_create_user_command("FixReadingImagePath", function()
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for i, line in ipairs(lines) do
	end

	-- to save the image paths
	local image_paths = {}
	-- save where to edit in the frontmatter
	local fm_beg, fm_end = nil, nil
	for i, line in ipairs(lines) do
		if fm_beg == nil or fm_end == nil then
			if line:match("^%-%-%-") then
				if fm_beg == nil then
					fm_beg = i
				else
					fm_end = i
				end
			end
		end
		-- Repalce the image p
		lines[i] = line:gsub("./reading/_images", "/static/images/reading")
		-- Check for markdown image syntax ![xxx](yyy) and extract yyy
		for image in line:gmatch("!%[.-%]%((.-)%)") do
			fixed_image = image:gsub("./reading/_images", "/static/images/reading")
			table.insert(image_paths, fixed_image)
		end
	end

	-- if we have more than 0 images
	if #image_paths > 0 then
		local new_frontmatter = {}
		local inside_images = false

		for i = fm_beg + 1, fm_end - 1 do
			-- Look for the images key
			if not inside_images and lines[i]:match("^images:%s*$") then
				inside_images = true
			elseif inside_images and lines[i]:match("^%s*([^%s:]+):%s") then
				inside_images = false
			end
			if not inside_images then
				table.insert(new_frontmatter, lines[i])
			end
		end
		table.insert(new_frontmatter, "images:")
		for _, image_path in ipairs(image_paths) do
			table.insert(new_frontmatter, "  - " .. image_path)
		end

		local new_lines = {}
		vim.list_extend(new_lines, vim.list_slice(lines, 1, fm_beg))
		vim.list_extend(new_lines, new_frontmatter)
		vim.list_extend(new_lines, vim.list_slice(lines, fm_end, #lines))

		lines = new_lines
	end
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end, {})

-- functionality for editing file from lazygit
-- these are used by the lazygit setting
function EditLineFromLazygit(file_path, line)
	local path = vim.fn.expand("%:p")
	if path == file_path then
		vim.cmd(tostring(line))
	else
		vim.cmd("e " .. file_path)
		vim.cmd(tostring(line))
	end
end

function EditFromLazygit(file_path)
	local path = vim.fn.expand("%:p")
	vim.cmd("e " .. file_path)
	if path == file_path then
		return
	else
		vim.cmd("e " .. file_path)
	end
end

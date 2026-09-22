local uv = vim.uv or vim.loop
local config_root = uv.fs_realpath(vim.fn.stdpath("config")) or vim.fn.stdpath("config")
local dotfiles_root = vim.fn.fnamemodify(config_root, ":h")
local agent_dir = vim.env.PI_CODING_AGENT_DIR or (dotfiles_root .. "/pi/agent")

local function archive_after_days()
	local ok, lines = pcall(vim.fn.readfile, agent_dir .. "/extension-settings.yaml")
	if not ok then
		return nil
	end

	local section_indent
	for _, line in ipairs(lines) do
		local content = line:gsub("#.*$", ""):gsub("%s+$", "")
		local indent = #(content:match("^(%s*)") or "")
		if not section_indent then
			if content:match("^session%-picker:%s*$") then
				section_indent = indent
			end
		elseif content ~= "" and indent <= section_indent then
			break
		elseif indent > section_indent then
			local value = content:match("^%s+archive%-after%-days:%s*(.-)%s*$")
			if value then
				local days = tonumber(value)
				if days and days > 0 and days == math.floor(days) then
					return days
				end
				vim.notify(
					"session-picker.archive-after-days must be a positive integer; using the default",
					vim.log.levels.WARN,
					{ title = "pi-nvim" }
				)
				return nil
			end
		end
	end
	return nil
end

require("pi-integration").setup({
	binary = vim.env.PI_BINARY or "pi",
	agent_dir = agent_dir,
	provider = vim.env.PI_PROVIDER,
	model = vim.env.PI_MODEL,
	session_dir = vim.env.PI_SESSION_DIR,
	archive_after_days = archive_after_days(),
	show_thinking = true,
})

vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		require("pi-integration").open()
	end,
})

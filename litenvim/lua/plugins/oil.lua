vim.pack.add({ "https://github.com/stevearc/oil.nvim" })
require("oil").setup({
	keymaps = {
		["g?"] = { "actions.show_help", mode = "n" },
		["<CR>"] = "actions.select",
		-- turn these off because I use them for split navigation
		["<C-s>"] = false,
		["<C-h>"] = false,
		["<S-CR>"] = { "actions.select", opts = { vertical = true } },
		["<C-CR>"] = { "actions.select", opts = { horizontal = true } },
		["<C-t>"] = { "actions.select", opts = { tab = true } },
		["<C-p>"] = "actions.preview",
		["<C-c>"] = { "actions.close", mode = "n" },
		["<C-l>"] = false,
		-- e! does the same thing, so let's just remove it
		-- ["<C-l>"] = "actions.refresh",
		["-"] = { "actions.parent", mode = "n" },
		["_"] = { "actions.open_cwd", mode = "n" },
		["`"] = { "actions.cd", mode = "n" },
		["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
		["gs"] = { "actions.change_sort", mode = "n" },
		["gx"] = "actions.open_external",
		["g."] = { "actions.toggle_hidden", mode = "n" },
		["g\\"] = { "actions.toggle_trash", mode = "n" },
	},
})

-- Oil creates empty notes before Obsidian's asynchronous Templater hook runs.
local vault_roots = {}
for _, workspace in ipairs(require("utils.obsidian").workspaces()) do
	table.insert(vault_roots, vim.uv.fs_realpath(workspace.path))
end
vim.api.nvim_create_autocmd("User", {
	pattern = "OilActionsPost",
	group = vim.api.nvim_create_augroup("oil_vault_templates", { clear = true }),
	callback = function(event)
		if event.data.err then
			return
		end
		local pending = {}
		for _, action in ipairs(event.data.actions) do
			if action.type == "create" and action.entry_type == "file" then
				local scheme, path = require("oil.util").parse_url(action.url)
				if scheme == "oil://" and path:match("%.md$") then
					path = vim.uv.fs_realpath(path)
					for _, root in ipairs(vault_roots) do
						if path and path:sub(1, #root + 1) == root .. "/" then
							local relative = path:sub(#root + 2)
							if not relative:match("^projects/") and not relative:match("^templates/") then
								table.insert(pending, path)
							end
							break
						end
					end
				end
			end
		end
		if #pending > 0 and not vim.wait(2000, function()
			for _, path in ipairs(pending) do
				if vim.fn.getfsize(path) <= 0 then
					return false
				end
			end
			return true
		end, 50) then
			vim.notify("Timed out waiting for Obsidian templates; check Obsidian before editing.", vim.log.levels.WARN)
		end
	end,
})

vim.keymap.set({ "n", "x" }, "-", "<cmd>Oil<cr>", { desc = "Open parent directory" })

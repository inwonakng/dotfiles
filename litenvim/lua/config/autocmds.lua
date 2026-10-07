-- latex is special
vim.api.nvim_create_autocmd({ "FileType" }, {
	pattern = { "bib", "tex" },
	callback = function()
		vim.opt_local.conceallevel = 0
		vim.opt_local.wrap = true
		vim.bo.shiftwidth = 2
		vim.bo.tabstop = 2
	end,
})

-- filetypes that use 2 spaces for tab
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "lua", "javascript", "typescript", "json", "html", "css", "scss", "yaml", "markdown" },
	callback = function()
		vim.bo.expandtab = true
		vim.bo.shiftwidth = 2
		vim.bo.tabstop = 2
		vim.bo.softtabstop = 2
	end,
})

-- turn off wrap for certain filetypes
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "python", "lua" }, -- List the file types here
	callback = function()
		vim.opt_local.wrap = false
	end,
})

-- Obsidian with hledger. If in this directory, render as ledger filetype
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	group = vim.api.nvim_create_augroup("md_ledger", { clear = true }),
	pattern = {
		vim.env.HOME .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal/finance/journals/**.md",
		vim.env.HOME .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal/finance/journals/**.journal",
	},
	callback = function()
		vim.bo.filetype = "ledger"
		vim.opt_local.wrap = false
		vim.bo.shiftwidth = 4
		vim.bo.tabstop = 4
	end,
})

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
	callback = function()
		local highlight_yank = vim.hl.hl_op or vim.hl.on_yank
		highlight_yank()
	end,
})

-- numi calculator scratch buffer
vim.filetype.add({ extension = { numi = "numi" } })
vim.api.nvim_create_autocmd("FileType", {
	pattern = "numi",
	callback = function()
		require("utils.calc-mode").setup(vim.api.nvim_get_current_buf())
	end,
})

-- Remove exact entries from location lists, not from their source files.
vim.api.nvim_create_autocmd("FileType", {
	pattern = "qf",
	callback = function(event)
		if vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].loclist ~= 1 then
			return
		end

		local function delete_entries(first, last)
			local list = vim.fn.getloclist(0, { id = 0, idx = 0, items = 0 })
			if first > #list.items then
				return
			end
			last = math.min(last, #list.items)
			for index = last, first, -1 do
				table.remove(list.items, index)
			end

			if list.idx > last then
				list.idx = list.idx - (last - first + 1)
			elseif list.idx >= first then
				list.idx = first
			end
			vim.fn.setloclist(0, {}, "r", {
				id = list.id,
				items = list.items,
				idx = math.min(list.idx, #list.items),
			})
			vim.api.nvim_win_set_cursor(0, { math.min(first, math.max(1, #list.items)), 0 })
		end

		vim.keymap.set("n", "dd", function()
			local first = vim.fn.line(".")
			delete_entries(first, first + vim.v.count1 - 1)
		end, { buffer = event.buf, desc = "Delete location-list entry" })
		vim.keymap.set("x", "d", function()
			local first, last = vim.fn.line("v"), vim.fn.line(".")
			vim.cmd("normal! \27")
			delete_entries(math.min(first, last), math.max(first, last))
		end, { buffer = event.buf, desc = "Delete selected location-list entries" })
	end,
})

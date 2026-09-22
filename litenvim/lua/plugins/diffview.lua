vim.pack.add({ "https://github.com/sindrets/diffview.nvim" })

local function set_diff_text_highlight(_, winid, ctx)
	if not ctx.layout_name:match("^diff2_") then
		return
	end

	local highlight = ctx.symbol == "a" and "DiffviewDiffDeleteText"
		or ctx.symbol == "b" and "DiffviewDiffAddText"
	if not highlight then
		return
	end

	local mapping = "DiffText:" .. highlight
	local winhighlight, replacements = vim.wo[winid].winhighlight:gsub("DiffText:[^,]+", mapping)
	if replacements == 0 then
		winhighlight = winhighlight == "" and mapping or (winhighlight .. "," .. mapping)
	end
	vim.wo[winid].winhighlight = winhighlight
end

require("diffview").setup({
	hooks = {
		diff_buf_win_enter = set_diff_text_highlight,
	},
})

vim.api.nvim_create_user_command("DiffviewToggle", function()
	if require("diffview.lib").get_current_view() then
		vim.cmd("DiffviewClose")
	else
		vim.cmd("DiffviewOpen")
	end
end, {})

vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "Git file history (Diffview)" })
vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewToggle<cr>", { desc = "Toggle Diffview" })

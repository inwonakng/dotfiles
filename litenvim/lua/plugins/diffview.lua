vim.pack.add({ "https://github.com/sindrets/diffview.nvim" })

vim.api.nvim_create_user_command("DiffviewToggle", function()
	if require("diffview.lib").get_current_view() then
		vim.cmd("DiffviewClose")
	else
		vim.cmd("DiffviewOpen")
	end
end, {})

vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "Git file history (Diffview)" })
vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewToggle<cr>", { desc = "Toggle Diffview" })

return {
	"sindrets/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewFileHistory" },
	keys = {
		{ "<leader>gv", "<cmd>DiffviewOpen<CR>", desc = "Open Diffview" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory<CR>", desc = "Open Diffview File History" },
	},
}

return {
	"stevearc/overseer.nvim",
	cmd = {
		"OverseerOpen",
		"OverseerClose",
		"OverseerToggle",
		"OverseerRun",
		"OverseerShell",
		"OverseerTaskAction",
	},
	keys = {
		{ "<leader>ow", "<cmd>OverseerToggle<cr>", desc = "Task list" },
		{ "<leader>or", "<cmd>OverseerRun<cr>", desc = "Run task" },
	},
}

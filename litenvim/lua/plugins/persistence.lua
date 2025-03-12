-- close unnamed buffers -- this is for stuff like the compiler output window that stays open
local close_unnamed_buf = function()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		-- Check if buffer is valid, loaded, and unnamed
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
			local name = vim.api.nvim_buf_get_name(buf)
			-- If there's no buffer name, close it
			if name == "" then
				vim.cmd("bd " .. buf)
			end
		end
	end
end

return {
	"folke/persistence.nvim",
	event = "BufReadPre",
	opts = {},
	keys = {
		{
			"<leader>qs",
			function()
				require("persistence").load()
				close_unnamed_buf()
			end,
			desc = "Restore Session",
		},
		{
			"<leader>qS",
			function()
				require("persistence").select()
			end,
			desc = "Select Session",
		},
		{
			"<leader>ql",
			function()
				require("persistence").load({ last = true })
				close_unnamed_buf()
			end,
			desc = "Restore Last Session",
		},
		{
			"<leader>qd",
			function()
				require("persistence").stop()
			end,
			desc = "Don't Save Current Session",
		},
	},
}

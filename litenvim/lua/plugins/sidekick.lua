vim.pack.add({ "https://github.com/folke/sidekick.nvim" })

require("sidekick").setup({
	-- add any options here
	cli = {
		mux = {
			backend = "tmux",
			enabled = true,
		},
		-- prompts = {
		--   explain = function(ctx)
		--     return "Explain the following code:\n" .. ctx.buf
		--   end
		-- }
	},
	nes = {
		-- NES still kind of sucks. turn off for now.
		enabled = false,
	},
})

vim.keymap.set("n", "<Tab>", function()
	-- if there is a next edit, jump to it, otherwise apply it if any
	if not require("sidekick").nes_jump_or_apply() then
		return "<Tab>" -- fallback to normal tab
	end
end, { expr = true, desc = "Goto/Apply Next Edit Suggestion" })

vim.keymap.set({ "n", "t", "i", "x" }, "<c-.>", function()
	require("sidekick.cli").toggle()
end, { desc = "Sidekick Toggle" })

vim.keymap.set("n", "<leader>aa", function()
	require("sidekick.cli").toggle()
end, { desc = "Sidekick Toggle CLI" })

vim.keymap.set("n", "<leader>as", function()
	require("sidekick.cli").select()
end, { desc = "Select CLI" })

vim.keymap.set("n", "<leader>ad", function()
	require("sidekick.cli").close()
end, { desc = "Detach a CLI Session" })

vim.keymap.set({ "x", "n" }, "<leader>at", function()
	require("sidekick.cli").send({ msg = "{this}" })
end, { desc = "Send This" })

vim.keymap.set("n", "<leader>af", function()
	require("sidekick.cli").send({ msg = "{file}" })
end, { desc = "Send File" })

vim.keymap.set("x", "<leader>av", function()
	require("sidekick.cli").send({ msg = "{selection}" })
end, { desc = "Send Visual Selection" })

vim.keymap.set({ "n", "x" }, "<leader>ap", function()
	require("sidekick.cli").prompt()
end, { desc = "Sidekick Select Prompt" })

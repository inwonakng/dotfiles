vim.pack.add({ "https://github.com/ibhagwan/fzf-lua" })

local function symbols_filter(entry, ctx)
	if ctx.symbols_filter == nil then
		ctx.symbols_filter = {
			"Class",
			"Constructor",
			"Enum",
			"Field",
			"Function",
			"Interface",
			"Method",
			"Module",
			"Namespace",
			"Property",
			"Struct",
			"Trait",
		}
	end
	return vim.tbl_contains(ctx.symbols_filter, entry.kind)
end

local fzf_opts = {
	default = {
		["--no-scrollbar"] = true,
		-- ["--layout"] = "reverse",
		-- ["--info"] = "inline",
		["--pointer"] = " ",
		-- ["--marker"] = "✓ ",
		-- ["--height"] = "100%",
		-- ["--multi"] = true,
	},
}

local win_opts = {
	default = {
		title = " " .. vim.trim((fzf_opts.prompt or "Select"):gsub("%s*:%s*$", "")) .. " ",
		title_pos = "left",
		border = { "", "─", "", "", "", "", "", "" },
		height = 1.0,
		width = 1.0,
		row = 1.0,
		col = 0,
		preview = {
			layout = "vertical",
			vertical = "up:60%",
			border = "none",
		},
	},
}

local fzf = require("fzf-lua")
local config = fzf.config
local actions = fzf.actions

-- Quickfix
config.defaults.keymap.fzf["ctrl-q"] = "select-all+accept"
config.defaults.keymap.fzf["ctrl-u"] = "half-page-up"
config.defaults.keymap.fzf["ctrl-d"] = "half-page-down"
config.defaults.keymap.fzf["ctrl-x"] = "jump"
config.defaults.keymap.fzf["ctrl-f"] = "preview-page-down"
config.defaults.keymap.fzf["ctrl-b"] = "preview-page-up"
config.defaults.keymap.builtin["<c-f>"] = "preview-page-down"
config.defaults.keymap.builtin["<c-b>"] = "preview-page-up"

local img_previewer ---@type string[]?
for _, v in ipairs({
	{ cmd = "ueberzug", args = {} },
	{ cmd = "chafa", args = { "{file}", "--format=symbols" } },
	{ cmd = "viu", args = { "-b" } },
}) do
	if vim.fn.executable(v.cmd) == 1 then
		img_previewer = vim.list_extend({ v.cmd }, v.args)
		break
	end
end

-- this is why the lazy option is disabled
fzf.register_ui_select(function(fzf_opts, items)
	local winopts = vim.deepcopy(win_opts.default)
	-- ui.select doesn't have preview. So we will adjust the height
	winopts.height = 0.4
	return {
		winopts = winopts,
		fzf_opts = fzf_opts.default,
	}
end)

fzf.setup({
	fzf_colors = true,
	fzf_opts = fzf_opts.default,
	winopts = win_opts.default,
	defaults = {
		formatter = "path.dirname_first",
	},
	previewers = {
		builtin = {
			extensions = {
				["png"] = img_previewer,
				["jpg"] = img_previewer,
				["jpeg"] = img_previewer,
				["gif"] = img_previewer,
				["webp"] = img_previewer,
			},
			ueberzug_scaler = "fit_contain",
		},
	},
	files = {
		cwd_prompt = false,
		actions = {
			["ctrl-o"] = { actions.toggle_ignore },
			["ctrl-h"] = { actions.toggle_hidden },
		},
	},
	grep = {
		actions = {
			["ctrl-o"] = { actions.toggle_ignore },
			["ctrl-h"] = { actions.toggle_hidden },
		},
	},
	lsp = {
		symbols = {
			symbol_hl = function(s)
				return "TroubleIcon" .. s
			end,
			symbol_fmt = function(s)
				return s:lower() .. "\t"
			end,
			child_prefix = false,
		},
		code_actions = {
			previewer = vim.fn.executable("delta") == 1 and "codeaction_native" or nil,
		},
	},
	git = {
		status = {
			actions = {
				["Space"] = { fn = actions.git_stage_unstage, reload = true, exit = false },
			},
		},
	},
})

-- ft = "fzf" keymaps (buffer-local, set when fzf terminal opens)
vim.api.nvim_create_autocmd("FileType", {
	pattern = "fzf",
	callback = function()
		vim.keymap.set("t", "<c-j>", "<c-j>", { nowait = true, buffer = true })
		vim.keymap.set("t", "<c-k>", "<c-k>", { nowait = true, buffer = true })
	end,
})

vim.keymap.set("n", "<leader>,", function()
	require("fzf-lua").buffers({ sort_mru = true, sort_lastused = true })
end, { desc = "Switch Buffer" })
vim.keymap.set("n", "<leader>/", function()
	require("fzf-lua").live_grep()
end, { desc = "Grep" })
vim.keymap.set("n", "<leader>:", "<cmd>FzfLua command_history<cr>", { desc = "Command History" })
-- find
vim.keymap.set("n", "<leader>fb", "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>", { desc = "Buffers" })
-- easier shorthand for buffers
vim.keymap.set("n", "<leader>bb", "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>", { desc = "Buffers" })
vim.keymap.set("n", "<leader>ff", function()
	require("fzf-lua").files()
end, { desc = "Find Files (Root Dir)" })
vim.keymap.set("n", "<leader>fg", function()
	require("fzf-lua").git_files()
end, { desc = "Find Files (git-files)" })
-- git
vim.keymap.set("n", "<leader>gc", "<cmd>FzfLua git_commits<CR>", { desc = "Commits" })
vim.keymap.set("n", "<leader>gs", "<cmd>FzfLua git_status<CR>", { desc = "Status" })
-- search
vim.keymap.set("n", '<leader>s"', "<cmd>FzfLua registers<cr>", { desc = "Registers" })
vim.keymap.set("n", "<leader>sa", "<cmd>FzfLua autocmds<cr>", { desc = "Auto Commands" })
vim.keymap.set("n", "<leader>sb", "<cmd>FzfLua grep_curbuf<cr>", { desc = "Buffer" })
vim.keymap.set("n", "<leader>sc", "<cmd>FzfLua command_history<cr>", { desc = "Command History" })
vim.keymap.set("n", "<leader>sC", "<cmd>FzfLua commands<cr>", { desc = "Commands" })
vim.keymap.set("n", "<leader>sd", "<cmd>FzfLua diagnostics_document<cr>", { desc = "Document Diagnostics" })
vim.keymap.set("n", "<leader>sD", "<cmd>FzfLua diagnostics_workspace<cr>", { desc = "Workspace Diagnostics" })
vim.keymap.set("n", "<leader>sg", "<cmd>FzfLua live_grep<cr>", { desc = "Grep (Root Dir)" })
vim.keymap.set("n", "<leader>sG", "<cmd>FzfLua live_grep<cr>", { desc = "Grep (cwd)" })
vim.keymap.set("n", "<leader>sh", "<cmd>FzfLua help_tags<cr>", { desc = "Help Pages" })
vim.keymap.set("n", "<leader>sH", "<cmd>FzfLua highlights<cr>", { desc = "Search Highlight Groups" })
vim.keymap.set("n", "<leader>sj", "<cmd>FzfLua jumps<cr>", { desc = "Jumplist" })
vim.keymap.set("n", "<leader>sk", "<cmd>FzfLua keymaps<cr>", { desc = "Key Maps" })
vim.keymap.set("n", "<leader>sl", "<cmd>FzfLua loclist<cr>", { desc = "Location List" })
vim.keymap.set("n", "<leader>sM", "<cmd>FzfLua man_pages<cr>", { desc = "Man Pages" })
vim.keymap.set("n", "<leader>sm", "<cmd>FzfLua marks<cr>", { desc = "Jump to Mark" })
vim.keymap.set("n", "<leader>sR", "<cmd>FzfLua resume<cr>", { desc = "Resume" })
vim.keymap.set("n", "<leader>sq", "<cmd>FzfLua quickfix<cr>", { desc = "Quickfix List" })
vim.keymap.set("v", "<leader>sg", function()
	require("fzf-lua").grep_visual({
		prompt = "Grep selection > ",
	})
end, { desc = "Grep Selection" })
-- lsp keys
vim.keymap.set("n", "<leader>ss", function()
	require("fzf-lua").lsp_document_symbols({
		regex_filter = symbols_filter,
	})
end, { desc = "Goto Symbol" })
vim.keymap.set("n", "<leader>sS", function()
	require("fzf-lua").lsp_live_workspace_symbols({
		regex_filter = symbols_filter,
	})
end, { desc = "Goto Symbol (Workspace)" })
vim.keymap.set("n", "gd", function()
	require("fzf-lua").lsp_definitions({ jump1 = true, ignore_current_line = true })
end, { desc = "Goto Definition" })
vim.keymap.set("n", "gr", function()
	require("fzf-lua").lsp_references({ jump1 = true, ignore_current_line = true })
end, { desc = "Goto References", nowait = true })
vim.keymap.set("n", "gI", function()
	require("fzf-lua").lsp_implementations({ jump1 = true, ignore_current_line = true })
end, { desc = "Goto Implementation" })
vim.keymap.set("n", "gy", function()
	require("fzf-lua").lsp_typedefs({ jump1 = true, ignore_current_line = true })
end, { desc = "Goto T[y]pe Definition" })

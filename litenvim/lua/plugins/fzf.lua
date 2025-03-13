local winopts = {
	small = {
		no_preview = {
			height = 0.35,
			width = 0.65,
			preview = {
				hidden = "hidden",
			},
		},
	},
	medium = {
		flex = {
			height = 0.90,
			width = 0.75,
			preview = {
				layout = "flex",
			},
		},
		vertical = {
			height = 0.90,
			width = 0.75,
			preview = {
				layout = "vertical",
				vertical = "up:65%",
			},
		},
	},
	large = {
		vertical = {
			height = 0.9,
			width = 0.9,
			preview = {
				layout = "vertical",
				vertical = "up:65%",
			},
		},
	},
	full = {
		vertical = {
			fullscreen = true,
			preview = {
				layout = "vertical",
				vertical = "down:75%",
			},
		},
	},
}

return {
	"ibhagwan/fzf-lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = function(_, opts)
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

		return {
			"default-title",
			fzf_colors = true,
			fzf_opts = {
				["--no-scrollbar"] = true,
			},
			defaults = {
				-- formatter = "path.filename_first",
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
			winopts = winopts.large.vertical,
			files = {
				cwd_prompt = false,
				actions = {
					["alt-i"] = { actions.toggle_ignore },
					["alt-h"] = { actions.toggle_hidden },
				},
			},
			grep = {
				actions = {
					["alt-i"] = { actions.toggle_ignore },
					["alt-h"] = { actions.toggle_hidden },
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
		}
	end,
	config = function(_, opts)
		if opts[1] == "default-title" then
			-- use the same prompt for all pickers for profile `default-title` and
			-- profiles that use `default-title` as base profile
			local function fix(t)
				t.prompt = t.prompt ~= nil and " " or nil
				for _, v in pairs(t) do
					if type(v) == "table" then
						fix(v)
					end
				end
				return t
			end
			opts = vim.tbl_deep_extend("force", fix(require("fzf-lua.profiles.default-title")), opts)
			opts[1] = nil
		end
		require("fzf-lua").setup(opts)
	end,
	keys = {
		{ "<c-j>", "<c-j>", ft = "fzf", mode = "t", nowait = true },
		{ "<c-k>", "<c-k>", ft = "fzf", mode = "t", nowait = true },
		{
			"<leader>,",
			function()
				require("fzf-lua").buffers({ sort_mru = true, sort_lastused = true, winopts = winopts.medium.flex })
			end,
			-- "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>",
			desc = "Switch Buffer",
		},
		{
			"<leader>/",
			function()
				require("fzf-lua").live_grep()
			end,
			desc = "Grep",
		},
		{ "<leader>:", "<cmd>FzfLua command_history<cr>", desc = "Command History" },
		-- find
		{ "<leader>fb", "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>", desc = "Buffers" },
		{
			"<leader>ff",
			function()
				require("fzf-lua").files()
			end,
			desc = "Find Files (Root Dir)",
		},
		{
			"<leader>fg",
			function()
				require("fzf-lua").git_files()
			end,
			desc = "Find Files (git-files)",
		},
		-- git
		{ "<leader>gc", "<cmd>FzfLua git_commits<CR>", desc = "Commits" },
		{ "<leader>gs", "<cmd>FzfLua git_status<CR>", desc = "Status" },
		-- search
		{ '<leader>s"', "<cmd>FzfLua registers<cr>", desc = "Registers" },
		{ "<leader>sa", "<cmd>FzfLua autocmds<cr>", desc = "Auto Commands" },
		{ "<leader>sb", "<cmd>FzfLua grep_curbuf<cr>", desc = "Buffer" },
		{ "<leader>sc", "<cmd>FzfLua command_history<cr>", desc = "Command History" },
		{ "<leader>sC", "<cmd>FzfLua commands<cr>", desc = "Commands" },
		{ "<leader>sd", "<cmd>FzfLua diagnostics_document<cr>", desc = "Document Diagnostics" },
		{ "<leader>sD", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "Workspace Diagnostics" },
		{ "<leader>sg", "<cmd>FzfLua live_grep<cr>", desc = "Grep (Root Dir)" },
		{ "<leader>sG", "<cmd>FzfLua live_grep<cr>", desc = "Grep (cwd)", mode = { "n" } },
		{ "<leader>sh", "<cmd>FzfLua help_tags<cr>", desc = "Help Pages" },
		{ "<leader>sH", "<cmd>FzfLua highlights<cr>", desc = "Search Highlight Groups" },
		{ "<leader>sj", "<cmd>FzfLua jumps<cr>", desc = "Jumplist" },
		{ "<leader>sk", "<cmd>FzfLua keymaps<cr>", desc = "Key Maps" },
		{ "<leader>sl", "<cmd>FzfLua loclist<cr>", desc = "Location List" },
		{ "<leader>sM", "<cmd>FzfLua man_pages<cr>", desc = "Man Pages" },
		{ "<leader>sm", "<cmd>FzfLua marks<cr>", desc = "Jump to Mark" },
		{ "<leader>sR", "<cmd>FzfLua resume<cr>", desc = "Resume" },
		{ "<leader>sq", "<cmd>FzfLua quickfix<cr>", desc = "Quickfix List" },
		{
			"<leader>sg",
			function()
				require("fzf-lua").grep_visual({
					prompt = "Grep selection > ",
				})
			end,
			desc = "Grep Selection",
			mode = { "v" },
		},
		-- lsp keys
		{
			"<leader>ss",
			function()
				require("fzf-lua").lsp_document_symbols({
					regex_filter = symbols_filter,
				})
			end,
			desc = "Goto Symbol",
		},
		{
			"<leader>sS",
			function()
				require("fzf-lua").lsp_live_workspace_symbols({
					regex_filter = symbols_filter,
				})
			end,
			desc = "Goto Symbol (Workspace)",
		},
		{
			"gd",
			function()
				require("fzf-lua").lsp_definitions({ jump1 = true, ignore_current_line = true })
			end,
			desc = "Goto Definition",
			-- has = "definition",
		},
		{
			"gr",
			function()
				require("fzf-lua").lsp_references({ jump1 = true, ignore_current_line = true })
			end,
			desc = "Goto References",
			nowait = true,
		},
		{
			"gI",
			function()
				require("fzf-lua").lsp_implementations({ jump1 = true, ignore_current_line = true })
			end,
			desc = "Goto Implementation",
		},
		{
			"gy",
			function()
				require("fzf-lua").lsp_typedefs({ jump1 = true, ignore_current_line = true })
			end,
			desc = "Goto T[y]pe Definition",
		},
	},
}

-- TODO:
-- in visual mode, grep the selected text and filter by file name

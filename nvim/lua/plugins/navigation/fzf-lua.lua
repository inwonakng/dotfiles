local fzf_winopts = require("utils.fzf_winopts")

-- return {
--   "ibhagwan/fzf-lua",
--   -- optional for icon support
--   dependencies = {
--     "nvim-tree/nvim-web-devicons",
--     {
--       "neovim/nvim-lspconfig",
--       ---@class PluginLspOpts
--       opts = function()
--         -- override lsp keymaps
--         local keys = require("lazyvim.plugins.lsp.keymaps").get()
--         vim.list_extend(keys, {
--           {
--             "gr",
--             function()
--               require("fzf-lua").lsp_references({ jump_to_single_result = true, winopts = fzf_winopts.large.vertical })
--             end,
--             desc = "Go to References",
--           },
--           {
--             "gd",
--             function()
--               require("fzf-lua").lsp_definitions({ jump_to_single_result = true, winopts = fzf_winopts.large.vertical })
--             end,
--             desc = "Go to Definitions",
--           },
--           {
--             "gD",
--             function()
--               require("fzf-lua").lsp_declarations({ jump_to_single_result = true, winopts = fzf_winopts.large.vertical })
--             end,
--             desc = "Go to Declarations",
--           },
--           {
--             "gi",
--             function()
--               require("fzf-lua").lsp_implementations({
--                 jump_to_single_result = true,
--                 winopts = fzf_winopts.large.vertical,
--               })
--             end,
--             desc = "Go to Implementations",
--           },
--           {
--             "gy",
--             function()
--               require("fzf-lua").lsp_typedefs({ jump_to_single_result = true, winopts = fzf_winopts.large.vertical })
--             end,
--             desc = "Go to Type Definitions",
--           },
--           -- unbind for comment
--           { "<leader>cc", false },
--           { "<leader>cl", vim.lsp.codelens.run, desc = "Run Codelens", mode = { "n", "v" }, has = "codeLens" },
--           -- { "<leader>cc", function() print("U typed cc!") end, desc = "test override", mode = { "n", "v" } },
--         })
--       end,
--     },
--   },
--   config = function()
--     -- calling `setup` is optional for customization
--     require("fzf-lua").setup({
--       keymap = {
--         -- These override the default tables completely
--         -- no need to set to `false` to disable a bind
--         -- delete or modify is sufficient
--         builtin = {
--           -- neovim `:tmap` mappings for the fzf win
--           ["<F1>"] = "toggle-help",
--           ["<F2>"] = "toggle-fullscreen",
--           -- Only valid with the 'builtin' previewer
--           ["<F3>"] = "toggle-preview-wrap",
--           ["<F4>"] = "toggle-preview",
--           -- Rotate preview clockwise/counter-clockwise
--           ["<F5>"] = "toggle-preview-ccw",
--           ["<F6>"] = "toggle-preview-cw",
--           ["}"] = "preview-page-down",
--           ["{"] = "preview-page-up",
--           ["<S-left>"] = "preview-page-reset",
--         },
--         fzf = {
--           -- fzf '--bind=' options
--           -- ["ctrl-z"]      = "abort",
--           -- ["ctrl-u"]      = "unix-line-discard",
--           ["ctrl-d"] = "half-page-down",
--           ["ctrl-u"] = "half-page-up",
--           ["ctrl-a"] = "beginning-of-line",
--           ["ctrl-e"] = "end-of-line",
--           ["alt-a"] = "toggle-all",
--           -- Only valid with fzf previewers (bat/cat/git/etc)
--           ["f3"] = "toggle-preview-wrap",
--           ["f4"] = "toggle-preview",
--           ["}"] = "preview-page-down",
--           ["{"] = "preview-page-up",
--         },
--       },
--     })
--   end,
--   keys = {
--     {
--       "<leader>r",
--       function()
--         require("fzf-lua").resume()
--       end,
--       desc = "Resume previous search",
--     },
--     {
--       "<leader><space>",
--       function()
--         local opts = {}
--         opts.winopts = fzf_winopts.large.vertical
--         require("fzf-lua").grep(opts)
--       end,
--       desc = "Search File Contents",
--     },
--     {
--       "<leader>sv",
--       function()
--         local opts = {}
--         opts.winopts = fzf_winopts.large.vertical
--         require("fzf-lua").grep_visual(opts)
--       end,
--       desc = "Search Visual Selection",
--       mode={"v"}
--     },
--     {
--       "<leader>sw",
--       function()
--         local opts = {}
--         opts.winopts = fzf_winopts.large.vertical
--         require("fzf-lua").grep_cword(opts)
--       end,
--       desc = "Search for current word",
--     },
--     {
--       "<leader>sW",
--       function()
--         local opts = {}
--         opts.winopts = fzf_winopts.large.vertical
--         require("fzf-lua").grep_cWORD(opts)
--       end,
--       desc = "Search for current WORD",
--     },
--     {
--       "<leader>sb",
--       function()
--         local opts = {}
--         opts.winopts = fzf_winopts.large.vertical
--         require("fzf-lua").grep_curbuf(opts)
--       end,
--       desc = "Search Visual Selection",
--     },
--     {
--       "<leader>ff",
--       function()
--         require("fzf-lua").files({
--           winopts = fzf_winopts.large.vertical,
--           formatter = "path.filename_first",
--         })
--       end,
--       desc = "Search Files",
--     },
--     {
--       "<C-s>",
--       function()
--         require("fzf-lua").buffers()
--       end,
--       desc = "Search Buffers",
--     },
--     {
--       "<leader>ss",
--       function()
--         require("fzf-lua").builtin()
--       end,
--       desc = "fzf-lua Built-in Commands",
--     },
--     {
--       "<leader>sm",
--       function()
--         require("fzf-lua").tmux_buffers()
--       end,
--       desc = "List Tmux Paste Buffers",
--     },
--     {
--       "<leader>sl",
--       function()
--         require("fzf-lua").lsp_finder({ winopts = fzf_winopts.large.vertical })
--       end,
--       desc = "View LSP finder",
--     },
--     {
--       "<leader>dd",
--       function()
--         require("fzf-lua").dap_commands()
--       end,
--       desc = "Debugger Commands",
--     },
--   },
-- }

return {
  "ibhagwan/fzf-lua",
  cmd = "FzfLua",
  opts = function(_, opts)
    local config = require("fzf-lua.config")
    local actions = require("fzf-lua.actions")

    -- Quickfix
    config.defaults.keymap.fzf["ctrl-q"] = "select-all+accept"
    config.defaults.keymap.fzf["ctrl-u"] = "half-page-up"
    config.defaults.keymap.fzf["ctrl-d"] = "half-page-down"
    config.defaults.keymap.fzf["ctrl-x"] = "jump"
    config.defaults.keymap.fzf["ctrl-f"] = "preview-page-down"
    config.defaults.keymap.fzf["ctrl-b"] = "preview-page-up"
    config.defaults.keymap.builtin["<c-f>"] = "preview-page-down"
    config.defaults.keymap.builtin["<c-b>"] = "preview-page-up"

    -- Trouble
    if LazyVim.has("trouble.nvim") then
      config.defaults.actions.files["ctrl-t"] = require("trouble.sources.fzf").actions.open
    end

    -- Toggle root dir / cwd
    config.defaults.actions.files["ctrl-r"] = function(_, ctx)
      local o = vim.deepcopy(ctx.__call_opts)
      o.root = o.root == false
      o.cwd = nil
      o.buf = ctx.__CTX.bufnr
      LazyVim.pick.open(ctx.__INFO.cmd, o)
    end
    config.defaults.actions.files["alt-c"] = config.defaults.actions.files["ctrl-r"]
    config.set_action_helpstr(config.defaults.actions.files["ctrl-r"], "toggle-root-dir")

    -- use the same prompt for all
    local defaults = require("fzf-lua.profiles.default-title")
    local function fix(t)
      t.prompt = t.prompt ~= nil and " " or nil
      for _, v in pairs(t) do
        if type(v) == "table" then
          fix(v)
        end
      end
    end
    fix(defaults)

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

    return vim.tbl_deep_extend("force", defaults, {
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
      -- Custom LazyVim option to configure vim.ui.select
      ui_select = function(fzf_opts, items)
        return vim.tbl_deep_extend("force", fzf_opts, {
          prompt = " ",
          winopts = {
            title = " " .. vim.trim((fzf_opts.prompt or "Select"):gsub("%s*:%s*$", "")) .. " ",
            title_pos = "center",
          },
        }, fzf_opts.kind == "codeaction" and {
          winopts = {
            layout = "vertical",
            -- height is number of items minus 15 lines for the preview, with a max of 80% screen height
            height = math.floor(math.min(vim.o.lines * 0.8 - 16, #items + 2) + 0.5) + 16,
            width = 0.5,
            preview = not vim.tbl_isempty(LazyVim.lsp.get_clients({ bufnr = 0, name = "vtsls" })) and {
              layout = "vertical",
              vertical = "down:15,border-top",
              hidden = "hidden",
            } or {
              layout = "vertical",
              vertical = "down:15,border-top",
            },
          },
        } or {
          winopts = {
            width = 0.5,
            -- height is number of items, with a max of 80% screen height
            height = math.floor(math.min(vim.o.lines * 0.8, #items + 2) + 0.5),
          },
        })
      end,
      winopts = {
        width = 0.8,
        height = 0.8,
        row = 0.5,
        col = 0.5,
        preview = {
          scrollchars = { "┃", "" },
        },
      },
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
    })
  end,
  config = function(_, opts)
    require("fzf-lua").setup(opts)
  end,
  init = function()
    LazyVim.on_very_lazy(function()
      vim.ui.select = function(...)
        require("lazy").load({ plugins = { "fzf-lua" } })
        local opts = LazyVim.opts("fzf-lua") or {}
        require("fzf-lua").register_ui_select(opts.ui_select or nil)
        return vim.ui.select(...)
      end
    end)
  end,
  keys = {
    { "<c-j>", "<c-j>", ft = "fzf", mode = "t", nowait = true },
    { "<c-k>", "<c-k>", ft = "fzf", mode = "t", nowait = true },
    {
      "<leader>,",
      "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>",
      desc = "Switch Buffer",
    },
    { "<leader>/", LazyVim.pick("live_grep"), desc = "Grep (Root Dir)" },
    { "<leader>:", "<cmd>FzfLua command_history<cr>", desc = "Command History" },
    { "<leader><space>", LazyVim.pick("files"), desc = "Find Files (Root Dir)" },
    -- find
    { "<leader>fb", "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>", desc = "Buffers" },
    { "<leader>fc", LazyVim.pick.config_files(), desc = "Find Config File" },
    { "<leader>ff", LazyVim.pick("files"), desc = "Find Files (Root Dir)" },
    { "<leader>fF", LazyVim.pick("files", { root = false }), desc = "Find Files (cwd)" },
    { "<leader>fg", "<cmd>FzfLua git_files<cr>", desc = "Find Files (git-files)" },
    { "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "Recent" },
    { "<leader>fR", LazyVim.pick("oldfiles", { cwd = vim.uv.cwd() }), desc = "Recent (cwd)" },
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
    { "<leader>sg", LazyVim.pick("live_grep"), desc = "Grep (Root Dir)" },
    { "<leader>sG", LazyVim.pick("live_grep", { root = false }), desc = "Grep (cwd)" },
    { "<leader>sh", "<cmd>FzfLua help_tags<cr>", desc = "Help Pages" },
    { "<leader>sH", "<cmd>FzfLua highlights<cr>", desc = "Search Highlight Groups" },
    { "<leader>sj", "<cmd>FzfLua jumps<cr>", desc = "Jumplist" },
    { "<leader>sk", "<cmd>FzfLua keymaps<cr>", desc = "Key Maps" },
    { "<leader>sl", "<cmd>FzfLua loclist<cr>", desc = "Location List" },
    { "<leader>sM", "<cmd>FzfLua man_pages<cr>", desc = "Man Pages" },
    { "<leader>sm", "<cmd>FzfLua marks<cr>", desc = "Jump to Mark" },
    { "<leader>sR", "<cmd>FzfLua resume<cr>", desc = "Resume" },
    { "<leader>sq", "<cmd>FzfLua quickfix<cr>", desc = "Quickfix List" },
    { "<leader>sw", LazyVim.pick("grep_cword"), desc = "Word (Root Dir)" },
    { "<leader>sW", LazyVim.pick("grep_cword", { root = false }), desc = "Word (cwd)" },
    { "<leader>sw", LazyVim.pick("grep_visual"), mode = "v", desc = "Selection (Root Dir)" },
    { "<leader>sW", LazyVim.pick("grep_visual", { root = false }), mode = "v", desc = "Selection (cwd)" },
    { "<leader>uC", LazyVim.pick("colorschemes"), desc = "Colorscheme with Preview" },
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
  },
}


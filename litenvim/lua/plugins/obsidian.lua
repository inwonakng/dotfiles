return {
  "epwalsh/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  lazy = true,
  ft = "markdown",
  keys = {
    { "<leader>ot", "<cmd>ObsidianTemplate<cr>", desc = "Insert template" },
    { "<leader>oT", "<cmd>ObsidianTemplate default.md<cr>", desc = "Insert default template" },
    { "<leader>od", "<cmd>ObsidianToday<cr>", desc = "Create a daily note" },
    { "<leader>oo", "<cmd>ObsidianOpen<cr>", desc = "Open in Obsidian" },
    { "<C-CR>", "<cmd>ObsidianFollowLink vsp<cr>", desc = "Follow link in vsplit" },
    { "<S-CR>", "<cmd>ObsidianFollowLink hsplit<cr>", desc = "Follow link in hsplit" },
    { "<leader>oD", "<cmd>ObsidianDailies<cr>", desc = "Follow link" },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  opts = {
    completion = {
      nvim_cmp = false,
    },
    workspaces = {
      {
        name = "notes-work",
        path = vim.env.HOME .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/work",
      },
      {
        name = "notes-personal",
        -- path = "~/Documents/notes/personal",
        path = vim.env.HOME .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal",
      },
    },
    templates = {
      subdir = "templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
      -- A map for custom variables, the key should be the variable and the value a function
      substitutions = {},
    },
    daily_notes = {
      folder = "daily",
      date_format = "%Y-%m-%d",
      template = "default",
    },
    disable_frontmatter = true,
    note_frontmatter_func = function(note)
      -- This is equivalent to the default frontmatter function.
      local out = { tags = note.tags, title = "", summary = "", anoterhone = "" }
      -- `note.metadata` contains any manually added fields in the frontmatter.
      -- So here we just make sure those fields are kept in the frontmatter.
      if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
        for k, v in pairs(note.metadata) do
          -- print(k,v)
          out[k] = v
        end
      end
      -- print(vim.inspect(out))
      -- table.insert( out, {summary=""} )
      -- print("inserted to table!")
      return out
    end,
    picker = {
      name = "fzf-lua",
    },
    follow_url_func = function(url)
      vim.fn.jobstart({ "open", url }) -- Mac OS
    end,
    ui = {
      enable = false,
      checkboxes = {
        [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
        ["x"] = { char = "", hl_group = "ObsidianDone" },
      },
    },
  },
}

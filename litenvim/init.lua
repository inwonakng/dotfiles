require("config.options")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    error("Error cloning lazy.nvim:\n" .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { import = "plugins" },
  { "nvim-tree/nvim-web-devicons" },
}, {
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = "⌘",
      config = "🛠",
      event = "📅",
      ft = "📂",
      init = "⚙",
      keys = "🗝",
      plugin = "🔌",
      runtime = "💻",
      require = "🌙",
      source = "📄",
      start = "🚀",
      task = "📌",
      lazy = "💤 ",
    },
  },
  performance = {
    cache = {
      enabled = true,
    },
    rtp = {
      disabled_plugins = {
        -- "matchit",
        -- "matchparen",
        "netrwPlugin",
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

vim.cmd.colorscheme("catppuccin")

-- register the ui_select
local ui_select = function(fzf_opts, items)
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
end

vim.ui.select = function(...)
  require("lazy").load({ plugins = { "fzf-lua" } })
  require("fzf-lua").register_ui_select(ui_select or nil)
  return vim.ui.select(...)
end

-- additional settings. Separated like how lazyvim does it.
require("config.keymaps")
require("config.commands")
require("config.autocmds")

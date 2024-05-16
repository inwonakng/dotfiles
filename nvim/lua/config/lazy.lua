local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  -- bootstrap lazy.nvim
  -- stylua: ignore
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(vim.env.LAZY or lazypath)

require("config.commands")

local plugins = {
  -- add LazyVim and import its plugins
  -- override the theme and some icons
  {
    "LazyVim/LazyVim",
    import = "lazyvim.plugins",
    opts = {
      colorscheme = "catppuccin",
      icons = {
        kinds = {
          Folder = "󰉋 ",
        },
      },
    },
  },
  { import = "lazyvim.plugins.extras.vscode" },
  { import = "plugins.ui" },
  { import = "plugins.utility" },
  { import = "plugins.navigation" },
  { import = "plugins.editor" },
  { import = "plugins.lang" },
  { import = "plugins.lang.markdown" },
  { import = "plugins.lang.latex" },
  { import = "plugins.lang.hledger" },
  -- { import = "plugins.lang.python" },
  { import = "plugins.debugging" },
  { import = "plugins.terminal" },
}

local opts = {
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  ui = { border = "rounded" },
  checker = { enabled = true }, -- automatically check for plugin updates
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
}

require("lazy").setup(plugins, opts)

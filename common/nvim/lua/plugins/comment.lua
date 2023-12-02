-- add this to your lua/plugins.lua, lua/plugins/init.lua,  or the file you keep your other plugins:
return {
  "numToStr/Comment.nvim",
  vscode=true,
  opts = {
    ignore = "^$",
    toggler = {
      ---Line-comment toggle keymap
      line = "<leader>cc",
      ---Block-comment toggle keymap
      block = "<leader>cb",
    },
    ---LHS of operator-pending mappings in NORMAL and VISUAL mode
    opleader = {
      ---Line-comment keymap
      line = "<leader>cc",
      ---Block-comment keymap
      block = "<leader>cb",
    }, -- add any options here
    pre_hook = require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook(),
  },
  lazy = false,
}

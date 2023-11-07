-- add this to your lua/plugins.lua, lua/plugins/init.lua,  or the file you keep your other plugins:
return {
  "numToStr/Comment.nvim",
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
  },
  lazy = false,
}

return {
  "danymat/neogen",
  dependencies = "nvim-treesitter/nvim-treesitter",
  opts = {
    snippet_engine = "luasnip",
    languages = {
      python = {
        template = {
          annotation_convention = "google_docstrings",
        },
      },
    },
  },
  keys = {
    { "<leader>nc", "<cmd>lua require('neogen').generate({type='class'})<CR>", desc = "Generate docstring for class" },
    {
      "<leader>nf",
      "<cmd>lua require('neogen').generate({type='func'})<CR>",
      desc = "Generate docstring for function",
    },
    { "<leader>nF", "<cmd>lua require('neogen').generate({type='file'})<CR>", desc = "Generate docstring for file" },
  },
  -- config = true,
}

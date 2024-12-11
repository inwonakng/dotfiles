local disabled_plugins = {
  "lukas-reineke/indent-blankline.nvim",
  "echasnovski/mini.indentscope",
  "zbirenbaum/copilot-cmp",
  "nvim-telescope/telescope.nvim",
  "nvim-neo-tree/neo-tree.nvim",
  "MeanderingProgrammer/render-markdown.nvim",
}

local disabled_config = {}
for _, value in ipairs(disabled_plugins) do
  table.insert(disabled_config, {
    value,
    enabled = false,
  })
end

return disabled_config

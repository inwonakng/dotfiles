return {
  "hrsh7th/nvim-cmp",
  -- dependencies = {
  --   "copliot-cmp"
  -- },
  -- sources = {
  --   { name = 'vimtex', group_index = 2}
  -- },
  -- @param opts cmp.ConfigSchema
  opts = function(_, opts)
    local cmp = require("cmp")
    opts.window = {
      completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
    }
    cmp.config.enabled = function()
      local disabled = false
      disabled = disabled or (vim.api.nvim_buf_get_option(0, "buftype") == "prompt")
      -- disabled = disabled or (vim.fn.reg_recording() ~= '')
      -- disabled = disabled or (vim.fn.reg_executing() ~= '')
      return not disabled
    end
    cmp.mapping.preset.insert({
      ["<Tab>"] = vim.schedule_wrap(function(fallback)
        if cmp.visible() and has_words_before() then
          cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
        else
          fallback()
        end
      end),
    })
    table.insert(opts.sources, 1, {
      name = "copilot",
      group_index = 1,
      priority = 100,
    })
    -- table.insert(opts.sources, 1, {
    --   name = "vimtex",
    --   group_index = 1,
    --   priority = 100,
    -- })
  end,
}

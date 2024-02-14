return {
  "mfussenegger/nvim-dap-python",
  config = function()
    -- Use the conda env currently activated.
    local conda_prefix = vim.fn.getenv("CONDA_PREFIX")
    if not s == nil and not s == "" then
      require("dap-python").setup(conda_prefix .. "/bin/python")
    end
  end,
}

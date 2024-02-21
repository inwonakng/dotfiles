return {
  "natecraddock/workspaces.nvim",
  opts = {
    path = vim.fn.stdpath("data") .. "/workspaces",
    cd_type = "global",
    -- sort the list of workspaces by name after loading from the workspaces path.
    sort = true,
    -- sort by recent use rather than by name. requires sort to be true
    mru_sort = true,
    -- option to automatically activate workspace when opening neovim in a workspace directory
    auto_open = false,
    -- enable info-level notifications after adding or removing a workspace
    notify_info = true,
    hooks = {
      open = function()
        require("persistence").load()
        end
    }
  },
  -- keys = {
  --   {"", "", desc=""}
  -- }
}

-- Loaded only by edit-popup.sh, after the user's normal Neovim configuration.
-- macOS commonly aliases /var and /tmp through /private; Neovim resolves them.
local path = assert(vim.uv.fs_realpath(assert(vim.env.HS_EDIT_POPUP_DIRECTORY) .. "/buffer.txt"))
local buffer = vim.api.nvim_get_current_buf()
assert(vim.api.nvim_buf_get_name(buffer) == path, "Edit popup buffer was not opened")
vim.bo[buffer].swapfile = false
vim.bo[buffer].undofile = false
vim.bo[buffer].fixeol = false
vim.o.backup = false
vim.o.writebackup = false
vim.o.shadafile = "NONE"

local group = vim.api.nvim_create_augroup("HammerspoonEditPopup", { clear = true })
local applying = false
local applyCommands = { wq = true, wqall = true, xit = true, xall = true, exit = true }
vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    callback = function(event)
        applying = false
        if event.match ~= ":" or vim.v.event.abort
            or vim.api.nvim_get_current_buf() ~= buffer then return end
        local ok, command = pcall(vim.api.nvim_parse_cmd, vim.fn.getcmdline(), {})
        applying = ok and applyCommands[command.cmd] == true and command.nextcmd == ""
        -- A failed write/quit must not authorize a later :q!.
        vim.schedule(function() applying = false end)
    end,
})
vim.keymap.set("n", "ZZ", function()
    applying = true
    local ok, err = pcall(vim.cmd, "wq")
    applying = false
    if not ok then vim.notify(err, vim.log.levels.ERROR) end
end, { buffer = buffer, desc = "Apply edit popup" })
vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
        if not applying or vim.v.dying ~= 0 or vim.v.exiting ~= 0
            or not vim.api.nvim_buf_is_valid(buffer) or vim.bo[buffer].modified
            or vim.api.nvim_buf_get_name(buffer) ~= path then return end
        -- The shell publishes completion only after Neovim actually exits cleanly.
        vim.fn.writefile({ "apply" }, vim.env.HS_EDIT_POPUP_DIRECTORY .. "/apply")
    end,
})
vim.fn.writefile({ "ready" }, vim.env.HS_EDIT_POPUP_DIRECTORY .. "/ready")

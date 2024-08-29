local create_cmd = vim.api.nvim_create_user_command

create_cmd("FindTag", function(opts)
  if not vim.tbl_contains({
    "NOTE",
    "TODO",
    "FIXME",
    "DEBUG",
  }, opts.args) then
    return
  end
  require("fzf-lua").grep({
    search = string.format([[%s:|%s!\(.*\)]], opts.args, string.lower(opts.args)),
    no_esc = true,
  })
end, {
  desc = "List fixmes",
  nargs = "?",
  complete = function()
    return {
      "NOTE",
      "TODO",
      "FIXME",
      "DEBUG",
    }
  end,
})

create_cmd("FormatFile", function(args)
  local range = nil
  if args.count ~= -1 then
    local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
    range = {
      start = { args.line1, 0 },
      ["end"] = { args.line2, end_line:len() },
    }
  end
  require("conform").format({ async = true, lsp_format = "fallback", range = range })
end, { range = true })

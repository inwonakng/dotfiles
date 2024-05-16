local create_cmd = vim.api.nvim_create_user_command

create_cmd('FindTag', function(opts)
  if not vim.tbl_contains({
    'NOTE',
    'TODO',
    'FIXME',
    'DEBUG',
  }, opts.args) then
    return
  end
  require('fzf-lua').grep({
    search = string.format([[%s:|%s!\(.*\)]], opts.args, string.lower(opts.args)),
    no_esc = true,
  })
end, {
  desc = 'List fixmes',
  nargs = '?',
  complete = function()
    return {
      'NOTE',
      'TODO',
      'FIXME',
      'DEBUG',
    }
  end,
})

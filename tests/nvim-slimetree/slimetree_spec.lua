local slimetree = require('nvim-slimetree.slimetree')

describe('slimetree.SlimeCurrentLine', function()
  it('sends the current line range to SlimeSend', function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'line1', 'line2', 'line3' })
    vim.api.nvim_win_set_cursor(0, { 2, 0 }) -- line 2

    local last_cmd
    local orig_cmd = vim.cmd
    vim.cmd = function(arg)
      last_cmd = arg
    end

    slimetree.SlimeCurrentLine()

    vim.cmd = orig_cmd
    assert.equals('2,2SlimeSend', last_cmd)
  end)
end)


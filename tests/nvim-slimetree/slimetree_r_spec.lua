local slimetree = require('nvim-slimetree.slimetree')

-- Helper: skip tests if Tree-sitter R parser is not available
local function ensure_r_parser_or_skip()
  local ok = pcall(function()
    -- get_parser will error if the language isn't installed
    return vim.treesitter.get_parser(0, 'r')
  end)
  if not ok then
    pending('Tree-sitter R parser not available; skipping integration tests')
    return false
  end
  return true
end

-- Utility to create a new buffer with lines and set ft=r
local function setup_r_buffer(lines)
  vim.cmd('enew')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = 'r'
end

describe('slimetree.goo_move (R integration)', function()
  before_each(function()
    -- Bypass goo_tabs requirement inside tests
    _G.use_goo = false
  end)

  it('skips comments and sends the next code line; moves cursor down', function()
    setup_r_buffer({
      '# comment',
      'x <- 1',
      '',
    })
    if not ensure_r_parser_or_skip() then return end

    vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- start on comment

    local last_cmd
    local orig_cmd = vim.cmd
    vim.cmd = function(arg)
      last_cmd = arg
    end

    slimetree.goo_move()

    vim.cmd = orig_cmd

    assert.equals('2,2SlimeSend', last_cmd)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    assert.equals(3, row)  -- moved to line after the sent range
    assert.equals(0, col)
  end)

  it('selects the full call expression and moves to next line', function()
    setup_r_buffer({
      'sum(c(1, 2))',
      '',
    })
    if not ensure_r_parser_or_skip() then return end

    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    local last_cmd
    local orig_cmd = vim.cmd
    vim.cmd = function(arg)
      last_cmd = arg
    end

    slimetree.goo_move()

    vim.cmd = orig_cmd

    assert.equals('1,1SlimeSend', last_cmd)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    assert.equals(2, row)
    assert.equals(0, col)
  end)
end)


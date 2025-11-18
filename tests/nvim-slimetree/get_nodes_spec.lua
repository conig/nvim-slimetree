local get_nodes = require('nvim-slimetree.get_nodes')

local function set_ft(ft)
  -- new scratch buffer to avoid affecting other tests
  vim.cmd('enew')
  vim.bo.filetype = ft
end

describe('get_nodes.get_nodes', function()
  it('returns R node tables for r/rmd/qmd', function()
    for _, ft in ipairs({ 'r', 'rmd', 'qmd' }) do
      set_ft(ft)
      local nodes = get_nodes.get_nodes()
      assert.is_table(nodes.acceptable)
      assert.is_table(nodes.skip)
      assert.is_table(nodes.root)
      assert.is_table(nodes.sub_roots)
      assert.is_table(nodes.bad_parents)
      -- A sanity check on a known R key
      assert.is_true(nodes.acceptable['call'])
    end
  end)

  it('returns python node tables for python', function()
    set_ft('python')
    local nodes = get_nodes.get_nodes()
    assert.is_table(nodes.acceptable)
    assert.is_true(nodes.acceptable['function_definition'])
    assert.is_table(nodes.skip)
  end)
end)


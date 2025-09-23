local utils = require('nvim-slimetree.utils')

describe('utils.in_set', function()
  it('returns true when key present with true', function()
    local set = { a = true, b = false, c = true }
    assert.is_true(utils.in_set('a', set))
    assert.is_true(utils.in_set('c', set))
  end)

  it('returns false when key absent or falsey', function()
    local set = { a = true, b = false }
    assert.is_false(utils.in_set('z', set))
    assert.is_false(utils.in_set('b', set))
  end)

  it('errors when second arg not a table', function()
    local ok, err = pcall(utils.in_set, 'a', 'not-a-table')
    assert.is_false(ok)
    assert.matches('Expected a table as the second argument', tostring(err))
  end)
end)

describe('utils.append', function()
  it('unions two boolean-map sets', function()
    local a = { x = true, y = true }
    local b = { y = true, z = true, w = false }
    local r = utils.append(a, b)
    assert.are.same({ x = true, y = true, z = true }, r)
  end)

  it('handles empty inputs', function()
    assert.are.same({}, utils.append({}, {}))
  end)
end)


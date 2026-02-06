local selector = require("nvim-slimetree.core.selector")

local function make_node(type_name)
  local node = {
    _type = type_name,
    _parent = nil,
    _children = {},
    _next = nil,
    _range = { 0, 0, 0, 0 },
  }

  function node:type()
    return self._type
  end

  function node:parent()
    return self._parent
  end

  function node:child_count()
    return #self._children
  end

  function node:child(index)
    return self._children[index + 1]
  end

  function node:next_sibling()
    return self._next
  end

  function node:range()
    return self._range[1], self._range[2], self._range[3], self._range[4]
  end

  return node
end

local function add_child(parent, child)
  table.insert(parent._children, child)
  child._parent = parent

  local count = #parent._children
  if count > 1 then
    parent._children[count - 1]._next = child
  end
end

local spec = {
  acceptable = { identifier = true, call = true },
  bad_parents = { argument_list = true },
  root = { module = true },
  sub_roots = { block = true },
  skip = { comment = true },
}

describe("core.selector acceptance", function()
  it("accepts node when type is allowed and no bad parent", function()
    local module = make_node("module")
    local call = make_node("call")
    local id = make_node("identifier")
    add_child(module, call)
    add_child(call, id)

    assert.is_true(selector.is_acceptable_node(id, spec))
  end)

  it("rejects node with bad parent before root", function()
    local module = make_node("module")
    local args = make_node("argument_list")
    local id = make_node("identifier")
    add_child(module, args)
    add_child(args, id)

    assert.is_false(selector.is_acceptable_node(id, spec))
  end)

  it("finds nearest acceptable ancestor", function()
    local module = make_node("module")
    local call = make_node("call")
    local unknown = make_node("unknown")
    add_child(module, call)
    add_child(call, unknown)

    local found = selector.find_smallest_acceptable_node(unknown, spec)
    assert.are.equal(call, found)
  end)

  it("walks source order through children then siblings", function()
    local module = make_node("module")
    local first = make_node("call")
    local second = make_node("identifier")
    local third = make_node("identifier")

    add_child(module, first)
    add_child(first, second)
    add_child(module, third)

    local next_from_first = selector.get_next_node_in_source_order(first)
    assert.are.equal(second, next_from_first)

    local next_from_second = selector.get_next_node_in_source_order(second)
    assert.are.equal(third, next_from_second)
  end)
end)

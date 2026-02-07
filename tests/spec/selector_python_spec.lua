local helpers = require("tests.spec.parser_helpers")

local lines = {
  "x = 1",
  "foo(x)",
  "",
  "if x:",
  "    foo(x)",
  "    y = x + 1",
}

local function in_set(value, allowed)
  return allowed[value] == true
end

describe("core.selector python integration", function()
  it("selects top-level assignment as a single chunk", function()
    local selection = helpers.select_range("python", lines, { row = 0, col = 0 })

    assert.is_true(selection.ok)
    assert.are.equal(0, selection.start_row)
    assert.are.equal(0, selection.end_row)
    assert.is_true(in_set(selection.node_type, { assignment = true, expression_statement = true }))
  end)

  it("selects expression_statement from inside a call argument", function()
    local selection = helpers.select_range("python", lines, { row = 1, col = 4 })

    assert.is_true(selection.ok)
    assert.are.equal(1, selection.start_row)
    assert.are.equal(1, selection.end_row)
    assert.are.equal("expression_statement", selection.node_type)
  end)

  it("selects the full if statement block from the if line", function()
    local selection = helpers.select_range("python", lines, { row = 3, col = 0 })

    assert.is_true(selection.ok)
    assert.are.equal(3, selection.start_row)
    assert.are.equal(5, selection.end_row)
    assert.are.equal("if_statement", selection.node_type)
  end)
end)

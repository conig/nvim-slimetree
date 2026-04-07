local helpers = require("tests.spec.parser_helpers")

local lines = {
  "x=1",
  "echo hi | sed 's/h/H/'",
  "if true; then",
  "  echo ok",
  "fi",
  "for i in a b; do",
  "  echo \"$i\"",
  "done",
}

local function in_set(value, allowed)
  return allowed[value] == true
end

describe("core.selector bash integration", function()
  it("selects assignment-like command chunks from the current line", function()
    local selection = helpers.select_range("bash", lines, { row = 0, col = 0 })

    assert.is_true(selection.ok)
    assert.are.equal(0, selection.start_row)
    assert.are.equal(0, selection.end_row)
    assert.is_true(in_set(selection.node_type, {
      variable_assignment = true,
      command = true,
      list = true,
    }))
  end)

  it("selects the pipeline/list instead of nested words", function()
    local selection = helpers.select_range("bash", lines, { row = 1, col = 8 })

    assert.is_true(selection.ok)
    assert.are.equal(1, selection.start_row)
    assert.are.equal(1, selection.end_row)
    assert.is_true(in_set(selection.node_type, {
      pipeline = true,
      list = true,
    }))
  end)

  it("selects full control-flow statements", function()
    local if_selection = helpers.select_range("bash", lines, { row = 2, col = 0 })
    assert.is_true(if_selection.ok)
    assert.are.equal(2, if_selection.start_row)
    assert.are.equal(4, if_selection.end_row)
    assert.are.equal("if_statement", if_selection.node_type)

    local for_selection = helpers.select_range("bash", lines, { row = 5, col = 0 })
    assert.is_true(for_selection.ok)
    assert.are.equal(5, for_selection.start_row)
    assert.are.equal(7, for_selection.end_row)
    assert.are.equal("for_statement", for_selection.node_type)
  end)
end)

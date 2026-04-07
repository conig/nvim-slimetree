local cursor = require("nvim-slimetree.core.cursor")

describe("core.cursor.compute_next_position", function()
  it("moves to line after end_row", function()
    local next_pos = cursor.compute_next_position(20, 4, 0)
    assert.are.same({ row = 6, col = 0 }, next_pos)
  end)

  it("clamps at end of buffer", function()
    local next_pos = cursor.compute_next_position(5, 4, 0)
    assert.are.same({ row = 5, col = 0 }, next_pos)
  end)

  it("supports custom default column", function()
    local next_pos = cursor.compute_next_position(10, 2, 3)
    assert.are.same({ row = 4, col = 3 }, next_pos)
  end)

  it("returns first row when buffer is empty", function()
    local next_pos = cursor.compute_next_position(0, 0, 1)
    assert.are.same({ row = 1, col = 1 }, next_pos)
  end)
end)

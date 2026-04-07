local M = {}

function M.compute_next_position(line_count, end_row, default_col)
  local col = default_col or 0
  if line_count <= 0 then
    return { row = 1, col = col }
  end

  local target_row_0 = math.min(end_row + 1, line_count - 1)
  return {
    row = target_row_0 + 1,
    col = col,
  }
end

return M

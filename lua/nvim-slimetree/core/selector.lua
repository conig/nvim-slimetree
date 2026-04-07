local utils = require("nvim-slimetree.utils")

local M = {}

local function is_root_node_type(node_type, spec)
  return utils.in_set(node_type, spec.root) or utils.in_set(node_type, spec.sub_roots)
end

function M.is_skip_node(node_type, spec)
  return utils.in_set(node_type, spec.skip)
end

local function has_bad_parent(node, spec)
  local roots = utils.union_sets(spec.root, spec.sub_roots)
  local parent = node:parent()

  while parent and not utils.in_set(parent:type(), roots) do
    if utils.in_set(parent:type(), spec.bad_parents) then
      return true
    end
    parent = parent:parent()
  end

  return false
end

function M.is_acceptable_node(node, spec)
  if not node then
    return false
  end
  if not utils.in_set(node:type(), spec.acceptable) then
    return false
  end
  return not has_bad_parent(node, spec)
end

function M.find_smallest_acceptable_node(node, spec)
  local current = node
  while current do
    if M.is_acceptable_node(current, spec) then
      return current
    end
    current = current:parent()
  end
  return nil
end

local function first_non_ws_col(line)
  local first = line:find("%S")
  if not first then
    return nil
  end
  return first - 1
end

local function get_node_at(bufnr, row, col)
  return vim.treesitter.get_node({
    bufnr = bufnr,
    pos = { row, col },
    ignore_injections = false,
  })
end

local function lift_same_row(node, spec, row)
  local current = node
  local parent = current:parent()

  while parent do
    if is_root_node_type(parent:type(), spec) then
      break
    end

    local parent_row = parent:range()
    if parent_row ~= row then
      break
    end

    current = parent
    parent = current:parent()
  end

  return current
end

function M.get_node_under_row(bufnr, row, spec)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  if line == "" then
    return nil
  end

  local col = first_non_ws_col(line)
  if not col then
    return nil
  end

  local line_length = #line
  local best_node = nil
  local best_span = -1

  while col < line_length do
    local node = get_node_at(bufnr, row, col)
    if not node then
      col = col + 1
    else
      local _, _, _, end_col = node:range()
      local candidate = lift_same_row(node, spec, row)
      local _, start_c, _, end_c = candidate:range()
      local span = end_c - start_c

      if not M.is_skip_node(candidate:type(), spec) and span > best_span then
        best_span = span
        best_node = candidate
      end

      col = math.max(col + 1, end_col)
    end
  end

  return best_node
end

function M.get_next_node_in_source_order(node)
  if not node then
    return nil
  end

  if node:child_count() > 0 then
    return node:child(0)
  end

  local current = node
  while current do
    local sibling = current:next_sibling()
    if sibling then
      return sibling
    end
    current = current:parent()
  end

  return nil
end

function M.find_next_acceptable_node(bufnr, current_row, current_col, spec)
  local node = get_node_at(bufnr, current_row, current_col)
  if not node then
    node = M.get_node_under_row(bufnr, current_row, spec)
    if not node then
      return nil
    end
  end

  node = M.get_next_node_in_source_order(node)

  while node do
    local start_row, start_col = node:range()
    local is_after_cursor = (start_row > current_row) or (start_row == current_row and start_col > current_col)

    if is_after_cursor and M.is_acceptable_node(node, spec) then
      return node
    end

    node = M.get_next_node_in_source_order(node)
  end

  return nil
end

function M.select_range(bufnr, cursor, spec)
  local row = cursor.row
  local col = cursor.col
  local last_row = vim.api.nvim_buf_line_count(bufnr) - 1

  while row <= last_row do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
    local is_empty = line:match("^%s*$") ~= nil

    local node = nil
    local should_skip = is_empty
    if not is_empty then
      node = M.get_node_under_row(bufnr, row, spec)
      should_skip = not node or M.is_skip_node(node:type(), spec)
    end

    if not should_skip then
      break
    end

    row = row + 1
    if row > last_row then
      return { ok = false, reason = "no_executable_chunk" }
    end
    col = 0
  end

  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  local is_empty = line:match("^%s*$") ~= nil
  local node = M.get_node_under_row(bufnr, row, spec)

  if not node then
    return { ok = false, reason = "no_node_under_cursor" }
  end

  local acceptable = nil
  if is_empty or M.is_skip_node(node:type(), spec) then
    acceptable = M.find_next_acceptable_node(bufnr, row, col, spec)
  else
    acceptable = M.find_smallest_acceptable_node(node, spec)
    if acceptable then
      local start_row, start_col = acceptable:range()
      if start_row == row and start_col > col then
        acceptable = M.find_next_acceptable_node(bufnr, row, col, spec)
      end
    else
      acceptable = M.find_next_acceptable_node(bufnr, row, col, spec)
    end
  end

  if not acceptable then
    return { ok = false, reason = "no_acceptable_chunk" }
  end

  local start_row, start_col, end_row, end_col = acceptable:range()
  return {
    ok = true,
    reason = "ok",
    node = acceptable,
    node_type = acceptable:type(),
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
  }
end

return M

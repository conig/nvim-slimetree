local M = {}

function M.in_set(value, set)
  return type(set) == "table" and set[value] == true
end

function M.union_sets(a, b)
  local out = {}
  for k, v in pairs(a or {}) do
    if v == true then
      out[k] = true
    end
  end
  for k, v in pairs(b or {}) do
    if v == true then
      out[k] = true
    end
  end
  return out
end

function M.notify(cfg, msg, level)
  if cfg and cfg.notify and cfg.notify.silent then
    return
  end
  vim.notify(msg, level or (cfg and cfg.notify and cfg.notify.level) or vim.log.levels.WARN)
end

function M.refresh_parser(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return false
  end

  local trees = parser:parse()
  local tree = trees and trees[1]
  if not tree then
    return false
  end

  local root = tree:root()
  if not root then
    return false
  end

  local _, _, end_row = root:range()
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if end_row < line_count - 1 or end_row > line_count + 5 then
    parser:invalidate(true)
    parser:parse()
  end

  return true
end

return M

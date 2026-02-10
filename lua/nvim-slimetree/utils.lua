local M = {}
local parser_tick_cache = {}

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

  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  if parser_tick_cache[bufnr] == tick then
    return true
  end

  parser:parse()
  parser_tick_cache[bufnr] = tick

  return true
end

return M

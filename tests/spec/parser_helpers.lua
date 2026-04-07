local config = require("nvim-slimetree.config")
local lang = require("nvim-slimetree.core.lang")
local selector = require("nvim-slimetree.core.selector")
local utils = require("nvim-slimetree.utils")

local M = {}

local function with_buffer(filetype, lines, fn)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = filetype

  local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok_parser or not parser then
    vim.api.nvim_buf_delete(bufnr, { force = true })
    error(
      string.format(
        "Missing Tree-sitter parser for '%s'. Run tests/scripts/bootstrap_parsers.sh first.",
        filetype
      )
    )
  end

  parser:parse()
  utils.refresh_parser(bufnr)

  local ok, result = pcall(fn, bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
  if not ok then
    error(result)
  end
  return result
end

function M.select_range(filetype, lines, cursor)
  local cfg = config.normalize()
  local spec, err = lang.resolve_for_filetype(filetype, cfg)
  assert.is_nil(err)
  assert.is_table(spec)

  return with_buffer(filetype, lines, function(bufnr)
    return selector.select_range(bufnr, cursor, spec)
  end)
end

return M

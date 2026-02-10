local cursor_core = require("nvim-slimetree.core.cursor")
local lang = require("nvim-slimetree.core.lang")
local selector = require("nvim-slimetree.core.selector")
local state = require("nvim-slimetree.state")
local transport = require("nvim-slimetree.core.transport")
local utils = require("nvim-slimetree.utils")

local M = {}
local deprecation_emitted = {}

local function warn_deprecation(key, msg)
  if deprecation_emitted[key] then
    return
  end
  deprecation_emitted[key] = true
  utils.notify(state.config, msg, vim.log.levels.WARN)
end

local function build_send_text(bufnr, start_row, end_row)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  return table.concat(lines, "\n")
end

local function send_to_repl(text, bufnr)
  return transport.send(text, {
    bufnr = bufnr,
    config = state.config,
  })
end

function M.send_line()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local text = build_send_text(bufnr, row, row)
  local send_result = send_to_repl(text, bufnr)
  if not send_result.ok then
    return send_result
  end

  return {
    ok = true,
    reason = "ok",
    start_row = row,
    end_row = row,
    transport = send_result,
  }
end

function M.send_current(opts)
  opts = opts or {}
  local cfg = state.config
  local bufnr = vim.api.nvim_get_current_buf()

  if cfg.repl.require_gootabs and not state.gootabs.started then
    local result = { ok = false, reason = "gootabs_required" }
    utils.notify(cfg, "gootabs is required by config but no session is active.", vim.log.levels.ERROR)
    return result
  end

  utils.refresh_parser(bufnr)

  local filetype = vim.bo[bufnr].filetype
  local node_spec, spec_err = lang.resolve_for_filetype(filetype, cfg)
  if not node_spec then
    local result = { ok = false, reason = spec_err or "unsupported_filetype" }
    utils.notify(cfg, "No node spec is configured for filetype: " .. filetype, vim.log.levels.WARN)
    return result
  end

  local win_cursor = vim.api.nvim_win_get_cursor(0)
  local selection = selector.select_range(bufnr, {
    row = win_cursor[1] - 1,
    col = win_cursor[2],
  }, node_spec)

  if not selection.ok then
    return selection
  end

  local should_move = cfg.cursor.move_after_send
  if opts.move_after_send ~= nil then
    should_move = opts.move_after_send
  end
  if opts.hold_position == true then
    should_move = false
  end

  local next_cursor = nil
  if should_move then
    next_cursor = cursor_core.compute_next_position(
      vim.api.nvim_buf_line_count(bufnr),
      selection.end_row,
      cfg.cursor.default_col
    )
    vim.api.nvim_win_set_cursor(0, { next_cursor.row, next_cursor.col })
  end

  local text = build_send_text(bufnr, selection.start_row, selection.end_row)
  local send_result = send_to_repl(text, bufnr)
  if not send_result.ok then
    return {
      ok = false,
      reason = send_result.reason or "send_failed",
      error = send_result.error,
      sent_range = {
        start_row = selection.start_row,
        end_row = selection.end_row,
      },
      node_type = selection.node_type,
      next_cursor = next_cursor,
      transport = send_result,
    }
  end

  return {
    ok = true,
    reason = "ok",
    sent_range = {
      start_row = selection.start_row,
      end_row = selection.end_row,
    },
    node_type = selection.node_type,
    next_cursor = next_cursor,
    transport = send_result,
  }
end

function M.goo_move(hold_position)
  warn_deprecation("goo_move", "slimetree.goo_move() is deprecated; use slimetree.send_current().")
  return M.send_current({ hold_position = hold_position == true })
end

function M.SlimeCurrentLine()
  warn_deprecation("SlimeCurrentLine", "slimetree.SlimeCurrentLine() is deprecated; use slimetree.send_line().")
  return M.send_line()
end

function M.goo_send(text)
  local payload = text
  if payload == nil or payload == "" then
    payload = "\n"
  end
  return send_to_repl(payload, vim.api.nvim_get_current_buf())
end

function M.transport_status()
  return transport.status()
end

function M.transport_restart()
  return transport.restart()
end

return M

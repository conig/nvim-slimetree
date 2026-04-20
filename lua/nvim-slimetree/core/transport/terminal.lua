local state = require("nvim-slimetree.state")

local M = {}

local function ensure_state()
  state.transport = state.transport or {}
  state.transport.stats = state.transport.stats or {}
  state.transport.stats.enqueued = state.transport.stats.enqueued or 0
  state.transport.stats.sent = state.transport.stats.sent or 0
  state.transport.stats.failed = state.transport.stats.failed or 0
  state.transport.stats.fallback = state.transport.stats.fallback or 0
  if state.transport.running == nil then
    state.transport.running = false
  end
  if state.transport.connected == nil then
    state.transport.connected = false
  end
end

local function bool_from_number(v)
  if type(v) == "number" then
    return v ~= 0
  end
  return not not v
end

local function resolve_slimetree_config(bufnr)
  local local_cfg = nil
  pcall(function()
    local_cfg = vim.b[bufnr].slimetree_terminal_config
  end)

  if type(local_cfg) == "table" then
    return local_cfg
  end

  if type(vim.g.slimetree_terminal_config) == "table" then
    return vim.g.slimetree_terminal_config
  end

  return nil
end

local function resolve_slime_config(bufnr)
  local local_cfg = nil
  pcall(function()
    local_cfg = vim.b[bufnr].slime_config
  end)

  if type(local_cfg) == "table" then
    return local_cfg
  end

  if type(vim.g.slime_default_config) == "table" then
    return vim.g.slime_default_config
  end

  return nil
end

local function resolve_slime_target(bufnr)
  local local_target = nil
  pcall(function()
    local_target = vim.b[bufnr].slime_target
  end)

  if type(local_target) == "string" and local_target ~= "" then
    return local_target
  end

  if type(vim.g.slime_target) == "string" and vim.g.slime_target ~= "" then
    return vim.g.slime_target
  end

  return nil
end

local function resolve_bracketed_paste(bracketed_opt)
  if type(bracketed_opt) == "boolean" then
    return bracketed_opt
  end

  if bracketed_opt == "auto" then
    return bool_from_number(vim.g.slime_bracketed_paste)
  end

  return false
end

local function resolve_target_config(bufnr)
  local cfg = resolve_slimetree_config(bufnr)
  if type(cfg) == "table" then
    return cfg
  end

  if resolve_slime_target(bufnr) == "neovim" then
    return resolve_slime_config(bufnr)
  end

  return nil
end

local function validate_terminal_buffer(bufnr)
  if type(bufnr) ~= "number" or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, "terminal_buffer_invalid"
  end

  local ok, buftype = pcall(function()
    return vim.bo[bufnr].buftype
  end)
  if not ok or buftype ~= "terminal" then
    return nil, "terminal_buffer_invalid"
  end

  local ok_channel, channel = pcall(vim.fn.getbufvar, bufnr, "&channel")
  local jobid = tonumber(channel)
  if not ok_channel or not jobid or jobid <= 0 then
    return nil, "terminal_job_missing"
  end

  return jobid
end

function M.resolve_target(bufnr)
  local cfg = resolve_target_config(bufnr)
  if type(cfg) ~= "table" then
    return nil, "terminal_target_missing"
  end

  local target = {
    bufnr = tonumber(cfg.bufnr),
    jobid = tonumber(cfg.jobid),
  }

  if target.bufnr ~= nil then
    local buf_jobid, err = validate_terminal_buffer(target.bufnr)
    if not buf_jobid then
      return nil, err
    end

    if target.jobid ~= nil and target.jobid ~= buf_jobid then
      return nil, "terminal_job_mismatch"
    end

    target.jobid = buf_jobid
  end

  if target.jobid == nil or target.jobid <= 0 then
    return nil, "terminal_job_missing"
  end

  return target
end

function M.can_send(bufnr)
  local target = M.resolve_target(bufnr)
  return target ~= nil
end

local function wrap_bracketed_paste(payload)
  local has_newline = payload:sub(-1) == "\n"
  if has_newline then
    payload = payload:sub(1, -2)
  end

  payload = "\27[200~" .. payload .. "\27[201~"
  if has_newline then
    payload = payload .. "\n"
  end

  return payload
end

function M.send(text, opts)
  ensure_state()

  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local transport_cfg = opts.transport_cfg or state.config.transport

  local raw_text = tostring(text or "")
  if raw_text == "" then
    return { ok = false, reason = "empty_payload" }
  end

  local payload = raw_text
  if transport_cfg.terminal.append_newline and payload:sub(-1) ~= "\n" then
    payload = payload .. "\n"
  end

  if resolve_bracketed_paste(transport_cfg.terminal.bracketed_paste) then
    payload = wrap_bracketed_paste(payload)
  end

  local target, target_err = M.resolve_target(bufnr)
  if not target then
    state.transport.connected = false
    state.transport.last_error = target_err or "terminal_target_missing"
    return {
      ok = false,
      reason = target_err or "terminal_target_missing",
      backend = "terminal",
    }
  end

  local ok, err = pcall(vim.api.nvim_chan_send, target.jobid, payload)
  if not ok then
    state.transport.connected = false
    state.transport.backend = "terminal"
    state.transport.last_error = tostring(err)
    state.transport.stats.failed = state.transport.stats.failed + 1
    return {
      ok = false,
      reason = "terminal_send_failed",
      backend = "terminal",
      error = tostring(err),
    }
  end

  state.transport.connected = true
  state.transport.backend = "terminal"
  state.transport.last_error = nil
  state.transport.stats.sent = state.transport.stats.sent + 1

  return {
    ok = true,
    reason = "ok",
    backend = "terminal",
    enqueued = false,
    queue_depth = 0,
    bufnr = target.bufnr,
    jobid = target.jobid,
  }
end

function M.status()
  ensure_state()

  return {
    backend = "terminal",
    mode = state.config.transport.mode,
    queue_depth = 0,
    running = false,
    connected = state.transport.connected,
    last_error = state.transport.last_error,
    stats = vim.deepcopy(state.transport.stats),
  }
end

function M.restart()
  state.reset_transport()
  return {
    ok = true,
    reason = "ok",
    backend = "terminal",
  }
end

return M

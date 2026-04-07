local slime = require("nvim-slimetree.core.transport.slime")
local state = require("nvim-slimetree.state")

local M = {}

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ensure_state()
  state.transport = state.transport or {}
  state.transport.queue = state.transport.queue or {}
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

function M.resolve_target(bufnr)
  local slime_cfg = resolve_slime_config(bufnr)
  if type(slime_cfg) ~= "table" then
    return nil, "tmux_target_missing"
  end

  local pane = slime_cfg.target_pane
  if pane == nil or tostring(pane) == "" then
    return nil, "tmux_target_missing"
  end

  local socket = slime_cfg.socket_name
  if socket == nil or tostring(socket) == "" then
    socket = "default"
  end

  return {
    target_pane = tostring(pane),
    socket_name = tostring(socket),
  }
end

function M.can_send(bufnr)
  local target = M.resolve_target(bufnr)
  return target ~= nil
end

local function build_tmux_argv(target, args)
  local cmd = { "tmux" }

  local socket = target and target.socket_name
  if socket and socket ~= "" then
    if socket:sub(1, 1) == "/" then
      table.insert(cmd, "-S")
    else
      table.insert(cmd, "-L")
    end
    table.insert(cmd, socket)
  end

  for _, arg in ipairs(args or {}) do
    table.insert(cmd, tostring(arg))
  end

  return cmd
end

local function build_tmux_cmd(target, args)
  local escaped = {}
  for _, part in ipairs(build_tmux_argv(target, args)) do
    table.insert(escaped, vim.fn.shellescape(part))
  end
  return table.concat(escaped, " ")
end

local function run_tmux(target, args, stdin_text, callback)
  local cb = vim.schedule_wrap(function(ok, err)
    callback(ok, err)
  end)

  if vim.system then
    vim.system(build_tmux_argv(target, args), { text = true, stdin = stdin_text }, function(out)
      if out.code == 0 then
        cb(true, nil)
      else
        cb(false, trim(out.stderr or out.stdout or "tmux_command_failed"))
      end
    end)
    return
  end

  local command = build_tmux_cmd(target, args)
  local output
  if stdin_text ~= nil then
    output = vim.fn.system(command, stdin_text)
  else
    output = vim.fn.system(command)
  end

  if vim.v.shell_error == 0 then
    cb(true, nil)
  else
    cb(false, trim(output))
  end
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

local function should_send_enter(enter_mode, payload)
  if enter_mode == "always" then
    return true
  end

  if enter_mode == "never" then
    return false
  end

  return payload:sub(-1) ~= "\n"
end

local function run_steps(target, steps, done)
  local idx = 1

  local function run_next()
    local step = steps[idx]
    if not step then
      done(true, nil)
      return
    end

    run_tmux(target, step.args, step.stdin, function(ok, err)
      if not ok then
        done(false, err)
        return
      end
      idx = idx + 1
      run_next()
    end)
  end

  run_next()
end

local function dispatch_send(payload, req, done)
  local transport_cfg = req.transport_cfg
  local tmux_cfg = transport_cfg.tmux
  local target = req.target

  local steps = {}

  if tmux_cfg.cancel_copy_mode then
    table.insert(steps, {
      args = { "send-keys", "-X", "-t", target.target_pane, "cancel" },
    })
  end

  table.insert(steps, {
    args = { "load-buffer", "-b", tmux_cfg.buffer_name, "-" },
    stdin = payload,
  })

  local paste_args = {
    "paste-buffer",
    "-d",
    "-b",
    tmux_cfg.buffer_name,
    "-t",
    target.target_pane,
  }

  if resolve_bracketed_paste(tmux_cfg.bracketed_paste) then
    table.insert(paste_args, 3, "-p")
  end

  table.insert(steps, {
    args = paste_args,
  })

  if should_send_enter(tmux_cfg.enter_mode, payload) then
    table.insert(steps, {
      args = { "send-keys", "-t", target.target_pane, "Enter" },
    })
  end

  run_steps(target, steps, done)
end

local function process_queue()
  ensure_state()

  if state.transport.running then
    return
  end

  local req = table.remove(state.transport.queue, 1)
  if not req then
    return
  end

  state.transport.running = true
  state.transport.backend = "tmux_native"

  dispatch_send(req.payload, req, function(ok, err)
    if ok then
      state.transport.connected = true
      state.transport.last_error = nil
      state.transport.stats.sent = state.transport.stats.sent + 1
    else
      state.transport.connected = false
      state.transport.last_error = err or "tmux_send_failed"
      state.transport.stats.failed = state.transport.stats.failed + 1

      if req.transport_cfg.fallback_to_slime then
        local fallback = slime.send(req.raw_text, { append_newline = true })
        if fallback.ok then
          state.transport.stats.fallback = state.transport.stats.fallback + 1
        end
      end
    end

    state.transport.running = false
    vim.schedule(process_queue)
  end)
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
  if transport_cfg.tmux.append_newline and payload:sub(-1) ~= "\n" then
    payload = payload .. "\n"
  end

  local target, target_err = M.resolve_target(bufnr)
  if not target then
    return { ok = false, reason = target_err or "tmux_target_missing" }
  end

  local async = transport_cfg.async
  if opts.async ~= nil then
    async = opts.async
  end

  if not async then
    local complete = false
    local success = false
    local dispatch_err = nil

    dispatch_send(payload, {
      raw_text = raw_text,
      payload = payload,
      target = target,
      transport_cfg = transport_cfg,
    }, function(ok, err)
      complete = true
      success = ok
      dispatch_err = err
    end)

    vim.wait(5000, function()
      return complete
    end, 5)

    if not complete then
      state.transport.connected = false
      state.transport.last_error = "tmux_send_timeout"
      return { ok = false, reason = "tmux_send_timeout" }
    end

    if success then
      state.transport.connected = true
      state.transport.last_error = nil
      state.transport.backend = "tmux_native"
      state.transport.stats.sent = state.transport.stats.sent + 1
      return {
        ok = true,
        reason = "ok",
        backend = "tmux_native",
        enqueued = false,
        queue_depth = #state.transport.queue,
      }
    end

    state.transport.connected = false
    state.transport.last_error = dispatch_err or "tmux_send_failed"
    state.transport.stats.failed = state.transport.stats.failed + 1
    return {
      ok = false,
      reason = "tmux_send_failed",
      error = dispatch_err,
    }
  end

  local max_queue = transport_cfg.max_queue or 256
  if #state.transport.queue >= max_queue then
    return {
      ok = false,
      reason = "transport_queue_full",
      backend = "tmux_native",
      queue_depth = #state.transport.queue,
    }
  end

  table.insert(state.transport.queue, {
    bufnr = bufnr,
    raw_text = raw_text,
    payload = payload,
    target = target,
    transport_cfg = transport_cfg,
  })

  state.transport.stats.enqueued = state.transport.stats.enqueued + 1
  vim.schedule(process_queue)

  return {
    ok = true,
    reason = "enqueued",
    backend = "tmux_native",
    enqueued = true,
    queue_depth = #state.transport.queue,
    target_pane = target.target_pane,
  }
end

function M.status()
  ensure_state()

  return {
    backend = "tmux_native",
    mode = state.config.transport.mode,
    queue_depth = #state.transport.queue,
    running = state.transport.running,
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
    backend = "tmux_native",
  }
end

return M

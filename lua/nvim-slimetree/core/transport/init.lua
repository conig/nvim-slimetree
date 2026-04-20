local slime = require("nvim-slimetree.core.transport.slime")
local state = require("nvim-slimetree.state")
local terminal = require("nvim-slimetree.core.transport.terminal")
local tmux_native = require("nvim-slimetree.core.transport.tmux_native")

local M = {}

local function send_with_slime(text)
  local out = slime.send(text, {
    append_newline = true,
  })
  state.transport.backend = "slime"
  state.transport.connected = out.ok
  if out.ok then
    state.transport.last_error = nil
  else
    state.transport.last_error = out.reason
  end
  return out
end

local function send_with_fallback(text, cfg, backend_name, result)
  if result.ok or not cfg.transport.fallback_to_slime then
    return result
  end

  local fallback = slime.send(text, { append_newline = true })
  if fallback.ok then
    state.transport.stats.fallback = (state.transport.stats.fallback or 0) + 1
    state.transport.last_error = nil
  end
  fallback.fallback_from = backend_name
  state.transport.backend = "slime"
  state.transport.connected = fallback.ok
  if not fallback.ok then
    state.transport.last_error = fallback.reason
  end
  return fallback
end

function M.resolve_backend(cfg, bufnr)
  local transport_cfg = (cfg and cfg.transport) or state.config.transport
  local selected = transport_cfg.backend or "auto"

  if selected == "auto" then
    if tmux_native.can_send(bufnr) then
      return "tmux_native"
    end
    if terminal.can_send(bufnr) then
      return "terminal"
    end
    return "slime"
  end

  if selected == "tmux_native" and not tmux_native.can_send(bufnr) then
    return "slime"
  end

  if selected == "tmux_native" then
    return "tmux_native"
  end

  if selected == "terminal" and not terminal.can_send(bufnr) then
    return "slime"
  end

  if selected == "terminal" then
    return "terminal"
  end

  return "slime"
end

function M.send(text, opts)
  opts = opts or {}
  local cfg = opts.config or state.config
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()

  local backend = M.resolve_backend(cfg, bufnr)
  local result

  if backend == "tmux_native" then
    result = tmux_native.send(text, {
      bufnr = bufnr,
      async = opts.async,
      transport_cfg = cfg.transport,
    })
    return send_with_fallback(text, cfg, "tmux_native", result)
  end

  if backend == "terminal" then
    result = terminal.send(text, {
      bufnr = bufnr,
      transport_cfg = cfg.transport,
    })
    return send_with_fallback(text, cfg, "terminal", result)
  end

  return send_with_slime(text)
end

function M.status()
  local backend = M.resolve_backend(state.config, vim.api.nvim_get_current_buf())
  if backend == "tmux_native" then
    return tmux_native.status()
  end

  if backend == "terminal" then
    return terminal.status()
  end

  return {
    backend = "slime",
    mode = state.config.transport.mode,
    queue_depth = 0,
    running = false,
    connected = true,
    last_error = nil,
    stats = vim.deepcopy(state.transport.stats or {}),
  }
end

function M.restart()
  local backend = M.resolve_backend(state.config, vim.api.nvim_get_current_buf())
  if backend == "tmux_native" then
    return tmux_native.restart()
  end
  if backend == "terminal" then
    return terminal.restart()
  end
  state.reset_transport()
  return {
    ok = true,
    reason = "ok",
    backend = "slime",
  }
end

return M

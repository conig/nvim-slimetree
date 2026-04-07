local slime = require("nvim-slimetree.core.transport.slime")
local state = require("nvim-slimetree.state")
local tmux_native = require("nvim-slimetree.core.transport.tmux_native")

local M = {}

function M.resolve_backend(cfg, bufnr)
  local transport_cfg = (cfg and cfg.transport) or state.config.transport
  local selected = transport_cfg.backend or "auto"

  if selected == "auto" then
    if tmux_native.can_send(bufnr) then
      return "tmux_native"
    end
    return "slime"
  end

  if selected == "tmux_native" and not tmux_native.can_send(bufnr) then
    return "slime"
  end

  if selected == "tmux_native" then
    return "tmux_native"
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

    if (not result.ok) and cfg.transport.fallback_to_slime then
      local fallback = slime.send(text, { append_newline = true })
      if fallback.ok then
        state.transport.stats.fallback = (state.transport.stats.fallback or 0) + 1
      end
      fallback.fallback_from = "tmux_native"
      state.transport.backend = "slime"
      state.transport.connected = fallback.ok
      return fallback
    end

    return result
  end

  local out = slime.send(text, {
    append_newline = true,
  })
  state.transport.backend = "slime"
  state.transport.connected = out.ok
  if not out.ok then
    state.transport.last_error = out.reason
  end
  return out
end

function M.status()
  local backend = M.resolve_backend(state.config, vim.api.nvim_get_current_buf())
  if backend == "tmux_native" then
    return tmux_native.status()
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
  return tmux_native.restart()
end

return M

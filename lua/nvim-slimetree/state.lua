local config = require("nvim-slimetree.config")

local M = {
  config = config.defaults(),
  gootabs = {
    started = false,
    panes = {},
    window_name = nil,
    target_index = nil,
  },
  transport = {
    queue = {},
    running = false,
    connected = false,
    last_error = nil,
    backend = nil,
    stats = {
      enqueued = 0,
      sent = 0,
      failed = 0,
      fallback = 0,
    },
  },
}

function M.reset_gootabs()
  M.gootabs.started = false
  M.gootabs.panes = {}
  M.gootabs.window_name = nil
  M.gootabs.target_index = nil
end

function M.reset_transport()
  M.transport.queue = {}
  M.transport.running = false
  M.transport.connected = false
  M.transport.last_error = nil
  M.transport.backend = nil
  M.transport.stats = {
    enqueued = 0,
    sent = 0,
    failed = 0,
    fallback = 0,
  }
end

return M

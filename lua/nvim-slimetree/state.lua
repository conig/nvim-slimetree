local config = require("nvim-slimetree.config")

local M = {
  config = config.defaults(),
  gootabs = {
    started = false,
    panes = {},
    window_name = nil,
    target_index = nil,
  },
}

function M.reset_gootabs()
  M.gootabs.started = false
  M.gootabs.panes = {}
  M.gootabs.window_name = nil
  M.gootabs.target_index = nil
end

return M

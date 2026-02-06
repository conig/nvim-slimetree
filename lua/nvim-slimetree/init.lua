local config = require("nvim-slimetree.config")
local state = require("nvim-slimetree.state")

local M = {}

M.gootabs = require("nvim-slimetree.gootabs")
M.slimetree = require("nvim-slimetree.slimetree")

function M.setup(opts)
  state.config = config.normalize(opts)

  if not state.config.gootabs.enabled then
    state.reset_gootabs()
  end

  _G.goo_started = state.gootabs.started
  _G.use_goo = state.config.gootabs.enabled

  if state.config.gootabs.enabled and state.config.gootabs.auto_start then
    vim.schedule(function()
      M.gootabs.start()
    end)
  end

  return vim.deepcopy(state.config)
end

function M.get_state()
  return {
    config = vim.deepcopy(state.config),
    gootabs = vim.deepcopy(state.gootabs),
  }
end

M.setup()

return M

local lang = require("nvim-slimetree.core.lang")
local state = require("nvim-slimetree.state")

local M = {}

function M.get_nodes(filetype)
  local ft = filetype or vim.bo.filetype
  return lang.resolve_for_filetype(ft, state.config)
end

return M

M = {}

M.get_nodes = function()
  local out = {}
  -- if filetype in set r, rmd, qmd
  if vim.bo.filetype == "r" or vim.bo.filetype == "rmd" or vim.bo.filetype == "qmd" then
    out.acceptable = require("nodes.R.acceptable")
    out.skip = require("nodes.R.skip")
    out.root = require("nodes.R.root")
    out.sub_roots = require("nodes.R.sub_root")
    out.bad_parents = require("nodes.R.bad_parents")
  end
  -- vim.notify(vim.inspect(out), "info", {title = "Nodes"})
  return out
end

return M

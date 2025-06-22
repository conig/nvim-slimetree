M = {}

M.get_nodes = function()
  local out = {}

  -- determine the language directory for node definitions
  local ft = vim.bo.filetype
  local lang_map = { rmd = "R", qmd = "R" }
  local lang_dir = lang_map[ft] or ft

  local ok, nodes = pcall(require, string.format("nodes.%s.acceptable", lang_dir))
  if ok then
    out.acceptable = nodes
    ok, nodes = pcall(require, string.format("nodes.%s.skip", lang_dir))
    out.skip = ok and nodes or {}
    ok, nodes = pcall(require, string.format("nodes.%s.root", lang_dir))
    out.root = ok and nodes or {}
    ok, nodes = pcall(require, string.format("nodes.%s.sub_root", lang_dir))
    out.sub_roots = ok and nodes or {}
    ok, nodes = pcall(require, string.format("nodes.%s.bad_parents", lang_dir))
    out.bad_parents = ok and nodes or {}
  end

  -- vim.notify(vim.inspect(out), "info", {title = "Nodes"})
  return out
end

return M

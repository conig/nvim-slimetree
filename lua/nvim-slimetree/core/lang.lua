local M = {}

local cache = {}

local REQUIRED_KEYS = {
  "acceptable",
  "skip",
  "root",
  "sub_roots",
  "bad_parents",
}

local function validate_spec(spec)
  for _, key in ipairs(REQUIRED_KEYS) do
    if type(spec[key]) ~= "table" then
      return false, "missing_node_key:" .. key
    end
  end
  return true
end

local function load_spec(language)
  if cache[language] then
    return cache[language]
  end

  local ok_acceptable, acceptable = pcall(require, "nodes." .. language .. ".acceptable")
  local ok_skip, skip = pcall(require, "nodes." .. language .. ".skip")
  local ok_root, root = pcall(require, "nodes." .. language .. ".root")
  local ok_sub, sub_roots = pcall(require, "nodes." .. language .. ".sub_root")
  local ok_bad, bad_parents = pcall(require, "nodes." .. language .. ".bad_parents")

  if not (ok_acceptable and ok_skip and ok_root and ok_sub and ok_bad) then
    return nil, "invalid_language_spec"
  end

  local spec = {
    acceptable = acceptable,
    skip = skip,
    root = root,
    sub_roots = sub_roots,
    bad_parents = bad_parents,
  }

  local valid, err = validate_spec(spec)
  if not valid then
    return nil, err
  end

  cache[language] = spec
  return spec
end

function M.resolve_for_filetype(filetype, cfg)
  local aliases = (cfg and cfg.language_aliases) or {}
  local language = aliases[filetype]
  if not language then
    return nil, "unsupported_filetype"
  end

  return load_spec(language)
end

function M.clear_cache()
  cache = {}
end

return M

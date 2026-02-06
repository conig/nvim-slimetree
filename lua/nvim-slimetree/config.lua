local M = {}

local function deepcopy(value)
  return vim.deepcopy(value)
end

local function merge_into(dst, src)
  for k, v in pairs(src or {}) do
    if type(v) == "table" and type(dst[k]) == "table" then
      merge_into(dst[k], v)
    else
      dst[k] = deepcopy(v)
    end
  end
end

local defaults = {
  repl = {
    require_gootabs = false,
  },
  cursor = {
    move_after_send = true,
    default_col = 0,
  },
  gootabs = {
    enabled = false,
    auto_start = false,
    window_name = "gooTabs",
    layout = "grid4",
    pane_count = 4,
    pane_commands = {},
    join_on_select = true,
    join_size = "33%",
    reset_layout_on_return = true,
  },
  notify = {
    silent = false,
    level = vim.log.levels.WARN,
  },
  language_aliases = {
    r = "R",
    rmd = "R",
    qmd = "R",
    quarto = "R",
    python = "python",
  },
}

function M.defaults()
  return deepcopy(defaults)
end

function M.normalize(user_opts)
  local cfg = M.defaults()
  merge_into(cfg, user_opts or {})

  if cfg.gootabs.layout == "single" then
    cfg.gootabs.pane_count = 1
  elseif cfg.gootabs.layout == "grid4" then
    cfg.gootabs.pane_count = 4
  elseif cfg.gootabs.layout == "none" then
    cfg.gootabs.pane_count = 0
  elseif cfg.gootabs.layout == "custom" and type(cfg.gootabs.pane_commands) == "table" then
    cfg.gootabs.pane_count = #cfg.gootabs.pane_commands
  end

  if cfg.gootabs.pane_count < 0 then
    cfg.gootabs.pane_count = 0
  end

  if cfg.notify.level == nil then
    cfg.notify.level = vim.log.levels.WARN
  end

  return cfg
end

return M

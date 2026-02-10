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
  transport = {
    backend = "auto",
    async = true,
    mode = "control",
    max_queue = 256,
    fallback_to_slime = true,
    tmux = {
      buffer_name = "slimetree_send",
      cancel_copy_mode = true,
      bracketed_paste = "auto",
      append_newline = true,
      enter_mode = "auto",
    },
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
    sh = "bash",
    bash = "bash",
    zsh = "bash",
    ksh = "bash",
  },
}

function M.defaults()
  return deepcopy(defaults)
end

function M.normalize(user_opts)
  local cfg = M.defaults()
  merge_into(cfg, user_opts or {})

  local valid_backend = {
    auto = true,
    tmux_native = true,
    slime = true,
  }
  if not valid_backend[cfg.transport.backend] then
    cfg.transport.backend = "auto"
  end

  cfg.transport.async = cfg.transport.async ~= false

  local valid_mode = {
    control = true,
    exec = true,
  }
  if not valid_mode[cfg.transport.mode] then
    cfg.transport.mode = "control"
  end

  if type(cfg.transport.max_queue) ~= "number" then
    cfg.transport.max_queue = 256
  end
  cfg.transport.max_queue = math.floor(cfg.transport.max_queue)
  if cfg.transport.max_queue < 1 then
    cfg.transport.max_queue = 1
  end

  cfg.transport.fallback_to_slime = cfg.transport.fallback_to_slime ~= false

  local valid_enter_mode = {
    auto = true,
    always = true,
    never = true,
  }
  if not valid_enter_mode[cfg.transport.tmux.enter_mode] then
    cfg.transport.tmux.enter_mode = "auto"
  end

  local bracketed = cfg.transport.tmux.bracketed_paste
  if bracketed ~= "auto" and type(bracketed) ~= "boolean" then
    cfg.transport.tmux.bracketed_paste = "auto"
  end

  cfg.transport.tmux.cancel_copy_mode = cfg.transport.tmux.cancel_copy_mode ~= false
  cfg.transport.tmux.append_newline = cfg.transport.tmux.append_newline ~= false

  if type(cfg.transport.tmux.buffer_name) ~= "string" or cfg.transport.tmux.buffer_name == "" then
    cfg.transport.tmux.buffer_name = "slimetree_send"
  end

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

local state = require("nvim-slimetree.state")
local utils = require("nvim-slimetree.utils")

local M = {}
local deprecation_emitted = {}

local function warn_deprecation(key, msg)
  if deprecation_emitted[key] then
    return
  end
  deprecation_emitted[key] = true
  utils.notify(state.config, msg, vim.log.levels.WARN)
end

local function set_compat_globals()
  _G.goo_started = state.gootabs.started
  _G.use_goo = state.config.gootabs.enabled
end

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function split_lines(text)
  local out = {}
  for line in (text or ""):gmatch("[^\r\n]+") do
    table.insert(out, trim(line))
  end
  return out
end

local function run_tmux(args)
  local escaped = {}
  for _, arg in ipairs(args) do
    table.insert(escaped, vim.fn.shellescape(tostring(arg)))
  end

  local cmd = "tmux " .. table.concat(escaped, " ")
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil, trim(output)
  end
  return trim(output), nil
end

local function set_slime_target(pane_id)
  local socket_path, socket_err = run_tmux({ "display-message", "-p", "#{socket_path}" })
  if not socket_path then
    return nil, socket_err or "failed_to_get_tmux_socket"
  end

  vim.g.slime_target = "tmux"
  vim.g.slime_default_config = {
    socket_name = socket_path,
    target_pane = pane_id,
  }
  vim.b.slime_config = vim.g.slime_default_config

  return true
end

local function get_session_name()
  return run_tmux({ "display-message", "-p", "#S" })
end

local function list_windows(session_name)
  local out, err = run_tmux({ "list-windows", "-t", session_name, "-F", "#{window_name}" })
  if not out then
    return nil, err
  end
  return split_lines(out)
end

local function window_exists(session_name, window_name)
  local windows, err = list_windows(session_name)
  if not windows then
    return false, err
  end

  for _, name in ipairs(windows) do
    if name == window_name then
      return true
    end
  end

  return false
end

local function list_panes(target)
  local out, err = run_tmux({ "list-panes", "-t", target, "-F", "#{pane_id}" })
  if not out then
    return nil, err
  end
  return split_lines(out)
end

local function get_pane_window(pane_id)
  local out = run_tmux({ "display-message", "-p", "-t", pane_id, "#{window_name}" })
  return out
end

local function resolve_window_name(opts)
  return (opts and opts.window_name) or state.config.gootabs.window_name
end

local function resolve_pane_count(opts)
  if opts and opts.pane_count ~= nil then
    return opts.pane_count
  end
  return state.config.gootabs.pane_count
end

local function resolve_pane_commands(opts)
  if opts and opts.pane_commands ~= nil then
    return opts.pane_commands
  end
  return state.config.gootabs.pane_commands
end

local function resolve_join_enabled(opts)
  if opts and opts.join_on_select ~= nil then
    return opts.join_on_select
  end
  return state.config.gootabs.join_on_select
end

local function resolve_join_size(opts)
  if opts and opts.join_size ~= nil then
    return opts.join_size
  end
  return state.config.gootabs.join_size
end

local function reset_layout_if_needed(window_name)
  if not state.config.gootabs.reset_layout_on_return then
    return
  end
  run_tmux({ "select-layout", "-t", window_name, "even-horizontal" })
end

function M.status()
  return vim.deepcopy(state.gootabs)
end

function M.start(opts)
  if not state.config.gootabs.enabled then
    local msg = "gootabs is disabled; enable it via setup({ gootabs = { enabled = true } })."
    utils.notify(state.config, msg, vim.log.levels.WARN)
    return { ok = false, reason = "gootabs_disabled" }
  end

  local session_name, session_err = get_session_name()
  if not session_name then
    utils.notify(state.config, "Failed to detect tmux session: " .. (session_err or "unknown"), vim.log.levels.ERROR)
    return { ok = false, reason = "tmux_session_missing" }
  end

  local window_name = resolve_window_name(opts)
  local pane_count = resolve_pane_count(opts)
  if pane_count <= 0 then
    return { ok = false, reason = "invalid_pane_count" }
  end

  local exists, exists_err = window_exists(session_name, window_name)
  if exists_err then
    utils.notify(state.config, "Failed to query tmux windows: " .. exists_err, vim.log.levels.ERROR)
    return { ok = false, reason = "tmux_query_failed" }
  end

  if exists then
    local _, kill_err = run_tmux({ "kill-window", "-t", session_name .. ":" .. window_name })
    if kill_err then
      utils.notify(state.config, "Failed to reset existing gootabs window: " .. kill_err, vim.log.levels.ERROR)
      return { ok = false, reason = "kill_window_failed" }
    end
  end

  local _, create_err = run_tmux({ "new-window", "-d", "-n", window_name, "-t", session_name .. ":" })
  if create_err then
    utils.notify(state.config, "Failed to create gootabs window: " .. create_err, vim.log.levels.ERROR)
    return { ok = false, reason = "create_window_failed" }
  end

  local initial_target = session_name .. ":" .. window_name .. ".0"
  for _ = 2, pane_count do
    local _, split_err = run_tmux({ "split-window", "-h", "-t", initial_target })
    if split_err then
      utils.notify(state.config, "Failed to split tmux pane: " .. split_err, vim.log.levels.ERROR)
      return { ok = false, reason = "split_failed" }
    end
  end

  if pane_count > 1 then
    run_tmux({ "select-layout", "-t", session_name .. ":" .. window_name, "even-horizontal" })
  end

  local pane_ids, panes_err = list_panes(session_name .. ":" .. window_name)
  if not pane_ids or #pane_ids == 0 then
    utils.notify(state.config, "Failed to collect tmux pane ids: " .. (panes_err or "unknown"), vim.log.levels.ERROR)
    return { ok = false, reason = "panes_missing" }
  end

  local commands = resolve_pane_commands(opts)
  for i, pane_id in ipairs(pane_ids) do
    local cmd = nil
    if type(commands) == "table" then
      cmd = commands[i]
    elseif type(commands) == "string" then
      cmd = commands
    end

    if type(cmd) == "string" and cmd ~= "" then
      run_tmux({ "send-keys", "-t", pane_id, cmd, "Enter" })
    end
  end

  set_slime_target(pane_ids[1])

  state.gootabs.started = true
  state.gootabs.panes = pane_ids
  state.gootabs.window_name = window_name
  state.gootabs.target_index = 1
  set_compat_globals()

  return {
    ok = true,
    reason = "ok",
    panes = vim.deepcopy(pane_ids),
    window_name = window_name,
  }
end

function M.stop(opts)
  local session_name = get_session_name()
  local window_name = resolve_window_name(opts)

  if session_name and window_name then
    local exists = window_exists(session_name, window_name)
    if exists then
      run_tmux({ "kill-window", "-t", session_name .. ":" .. window_name })
    end
  end

  state.reset_gootabs()
  set_compat_globals()
  return { ok = true, reason = "ok" }
end

function M.select(index, opts)
  if type(index) ~= "number" or index < 1 then
    return { ok = false, reason = "invalid_index" }
  end

  if not state.gootabs.started then
    if state.config.gootabs.auto_start then
      local started = M.start(opts)
      if not started.ok then
        return started
      end
    else
      return { ok = false, reason = "gootabs_not_started" }
    end
  end

  local pane_id = state.gootabs.panes[index]
  if not pane_id then
    return { ok = false, reason = "pane_not_found" }
  end

  local ok, target_err = set_slime_target(pane_id)
  if not ok then
    return { ok = false, reason = target_err or "slime_target_failed" }
  end

  local join_on_select = resolve_join_enabled(opts)
  if not join_on_select then
    state.gootabs.target_index = index
    set_compat_globals()
    return { ok = true, reason = "ok", pane_id = pane_id, joined = false }
  end

  local current_window, current_err = run_tmux({ "display-message", "-p", "#{window_name}" })
  if not current_window then
    return { ok = false, reason = current_err or "current_window_missing" }
  end

  local window_name = state.gootabs.window_name
  if current_window == window_name then
    return { ok = false, reason = "cannot_join_from_gootabs_window" }
  end

  local moved_any = false
  for _, pid in ipairs(state.gootabs.panes) do
    local pane_window = get_pane_window(pid)
    if pane_window and pane_window ~= window_name then
      local _, move_err = run_tmux({ "move-pane", "-d", "-s", pid, "-t", window_name })
      if not move_err then
        moved_any = true
      end
    end
  end

  if moved_any then
    reset_layout_if_needed(window_name)
  end

  local pane_window = get_pane_window(pane_id)
  if pane_window ~= current_window then
    local join_size = resolve_join_size(opts)
    local _, join_err = run_tmux({ "join-pane", "-h", "-d", "-s", pane_id, "-t", current_window, "-l", join_size })
    if join_err then
      return { ok = false, reason = join_err }
    end
  end

  state.gootabs.started = true
  state.gootabs.target_index = index
  set_compat_globals()

  return { ok = true, reason = "ok", pane_id = pane_id, joined = true }
end

function M.start_goo(commands, window_name)
  warn_deprecation("start_goo", "gootabs.start_goo() is deprecated; use gootabs.start().")
  local out = M.start({ pane_commands = commands, window_name = window_name })
  if out.ok then
    return out.panes
  end
  return {}
end

function M.end_goo(window_name)
  warn_deprecation("end_goo", "gootabs.end_goo() is deprecated; use gootabs.stop().")
  return M.stop({ window_name = window_name })
end

function M.summon_goo(n, window_name)
  warn_deprecation("summon_goo", "gootabs.summon_goo() is deprecated; use gootabs.select().")
  return M.select(n, { window_name = window_name })
end

return M

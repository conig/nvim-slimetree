local M = {}

local function exec_cmd(cmd, ignore_errors)
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 and not ignore_errors then
    vim.notify(string.format("Failed to execute command: %s\nError:%s", cmd, out), vim.log.levels.ERROR)
    return nil
  end
  return out
end
local function get_session()
  local out = exec_cmd("tmux display-message -p '#S'")
  return out and out:gsub("%s+", "") or nil
end

-- Function to create the gooTabs window with 4 panes
local function start_goo_impl(commands, window_name)
  window_name = window_name or "gooTabs"

  local session = get_session()
  if not session then
    vim.notify("Failed to retrieve tmux session name.", vim.log.levels.ERROR)
    return false
  end

  exec_cmd(string.format("tmux kill-window -t %s:%s 2>/dev/null", session, window_name), true)
  exec_cmd(string.format("tmux new-window -d -n %s -t %s:", window_name, session))
  for _ = 1, 3 do
    exec_cmd(string.format("tmux split-window -h -t %s:%s", session, window_name))
  end
  exec_cmd(string.format("tmux select-layout -t %s:%s even-horizontal", session, window_name))

  local out = exec_cmd(string.format("tmux list-panes -t %s:%s -F '#{pane_id}'", session, window_name))
  if not out then return false end

  local panes = {}
  for pid in out:gmatch("[^\r\n]+") do
    panes[#panes + 1] = pid:gsub("%s+", "")
  end
  if #panes ~= 4 then return false end

  for i, pid in ipairs(panes) do
    vim.fn.setenv(string.format("%s_%d", window_name, i), pid)
    vim.fn.setenv(string.format("GOO_PANE_%d", i), pid)
  end

  if commands then
    local send_cmds = {}
    for i, pid in ipairs(panes) do
      local cmd = type(commands) == "table" and commands[i] or commands
      if cmd and cmd ~= "" then
        table.insert(send_cmds, string.format("tmux send-keys -t %s %q Enter", pid, cmd))
      end
    end
    if #send_cmds > 0 then exec_cmd(table.concat(send_cmds, " ; ")) end
  end
  return true
end

-- Public async wrapper so pane creation doesn't block UI
function M.start_goo(commands, window_name)
  if _G.goo_busy then return end
  _G.goo_busy = true
  vim.schedule(function()
    local ok = start_goo_impl(commands, window_name)
    _G.goo_started = ok
    _G.goo_busy = false
  end)
end

-- End goo session by killing the window and clearing variables
function M.end_goo(window_name)
  window_name = window_name or "gooTabs"

  local session = get_session()
  if session then
    exec_cmd(string.format("tmux kill-window -t %s:%s 2>/dev/null", session, window_name), true)
  end

  for i = 1, 4 do
    vim.fn.setenv(string.format("%s_%d", window_name, i), nil)
    vim.fn.setenv(string.format("GOO_PANE_%d", i), nil)
  end

  _G.goo_started = false
  _G.goo_busy = false
  vim.notify("All goo panes and the '" .. window_name .. "' window have been closed.", vim.log.levels.INFO)
end

-- Function to summon a specific goo pane into the current window
-- Helper function to get the window name of a given pane
local function get_pane_window(pane_id)
	local output = exec_cmd(string.format("tmux display-message -p -t %s '#{window_name}'", pane_id))
	if output then
		return output:gsub("%s+", "") -- Trim whitespace
	else
		return nil
	end
end

-- Function to summon a specific goo pane into the current window
function M.summon_goo(n, window_name)
  if _G.goo_busy then
    vim.defer_fn(function() M.summon_goo(n, window_name) end, 50)
    return
  end
  window_name = window_name or "gooTabs"
  if type(n) ~= "number" or n < 1 or n > 4 then
    vim.notify("Please provide a pane number between 1 and 4.", vim.log.levels.ERROR)
    return
  end

  local pane_id = os.getenv(string.format("%s_%d", window_name, n))
    or os.getenv(string.format("GOO_PANE_%d", n))
  if not pane_id or pane_id == "" then
    if _G.goo_busy or _G.goo_started then
      vim.defer_fn(function() M.summon_goo(n, window_name) end, 50)
    else
      vim.notify("Pane ID not found. Make sure to run :StartGoo first.", vim.log.levels.ERROR)
    end
    return
  end

  local current_window = exec_cmd("tmux display-message -p '#{window_name}'")
  if not current_window then
    vim.notify("Failed to retrieve current window name.", vim.log.levels.ERROR)
    return
  end
  current_window = current_window:gsub("%s+", "")
  if current_window == window_name then
    vim.notify("Cannot summon panes within the 'gooTabs' window.", vim.log.levels.WARN)
    return
  end

  for i = 1, 4 do
    local pid = os.getenv(string.format("%s_%d", window_name, i))
      or os.getenv(string.format("GOO_PANE_%d", i))
    if pid and pid ~= "" then
      local pane_window = get_pane_window(pid)
      if pane_window and pane_window ~= window_name then
        exec_cmd(string.format("tmux move-pane -d -s %s -t %s", pid, window_name))
      end
    end
  end
  exec_cmd(string.format("tmux select-layout -t %s even-horizontal", window_name))

  local pane_window = get_pane_window(pane_id)
  if pane_window == current_window then
    vim.notify(string.format("Pane %d is already in the current window.", n), vim.log.levels.INFO)
    return
  end

  exec_cmd(string.format("tmux join-pane -h -d -s %s -t %s -l 33%%", pane_id, current_window))
  _G.goo_started = true
end

return M


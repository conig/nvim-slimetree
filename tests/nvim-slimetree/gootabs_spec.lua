local gootabs = require('nvim-slimetree.gootabs')

local function with_stubbed_system(map, fn)
  local orig_system = vim.fn.system
  local executed = {}
  vim.fn.system = function(cmd)
    local s = type(cmd) == 'table' and table.concat(cmd, ' ') or tostring(cmd)
    table.insert(executed, s)
    for match, out in pairs(map) do
      if s:find(match, 1, true) then
        -- ensure shell_error is reset to success using real system()
        pcall(orig_system, 'true')
        if type(out) == 'function' then
          return out(s) or ''
        end
        return out
      end
    end
    -- default: success, empty
    pcall(orig_system, 'true')
    return ''
  end
  local ok, err = pcall(fn, executed)
  vim.fn.system = orig_system
  if not ok then error(err) end
  return executed
end

describe('gootabs.start_goo', function()
  it('creates 4 panes, stores env, and configures slime', function()
    local system_map = {
      ["tmux display-message -p '#S'"] = "mysession\n",
      ["tmux list-windows -t mysession -F '#{window_name}'"] = "nvim\nother\n",
      ["tmux new-window -d -n TESTWIN -t mysession:"] = "",
      ["tmux split-window -h -t mysession:TESTWIN.0"] = "",
      ["tmux list-panes -t mysession:TESTWIN -F '#{pane_id}'"] = "%1\n%2\n%3\n%4\n",
      ["tmux display-message -p '#{socket_path}'"] = "/tmp/tmux-1234/default\n",
      ["tmux send-keys -t %1"] = "",
      ["tmux send-keys -t %2"] = "",
      ["tmux send-keys -t %3"] = "",
      ["tmux send-keys -t %4"] = "",
    }

    with_stubbed_system(system_map, function()
      local panes = gootabs.start_goo({ 'echo one', 'echo two', '', '' }, 'TESTWIN')
      assert.are.same({ '%1', '%2', '%3', '%4' }, panes)
      assert.equals('tmux', vim.g.slime_target)
      assert.is_table(vim.g.slime_default_config)
      assert.equals('%1', vim.g.slime_default_config.target_pane)
      assert.equals('%1', vim.fn.getenv('TESTWIN_1'))
      assert.equals('%2', vim.fn.getenv('TESTWIN_2'))
    end)
  end)
end)

describe('gootabs.end_goo', function()
  it('kills panes and unsets env vars', function()
    local system_map = {
      ["tmux list-panes -a -F '#{pane_id}'"] = "%1\n%2\n%3\n%4\n",
    }
    -- seed env vars as if created
    vim.fn.setenv('TESTWIN_1', '%1')
    vim.fn.setenv('TESTWIN_2', '%2')
    vim.fn.setenv('TESTWIN_3', '%3')
    vim.fn.setenv('TESTWIN_4', '%4')

    with_stubbed_system(system_map, function()
      local called = {}
      local orig_system = vim.fn.system
      vim.fn.system = function(cmd)
        local s = tostring(cmd)
        table.insert(called, s)
        if s:find("tmux list-panes -a -F", 1, true) then
          pcall(orig_system, 'true')
          return "%1\n%2\n%3\n%4\n"
        end
        if s:find("tmux kill-pane -t", 1, true) then
          pcall(orig_system, 'true')
          return ''
        end
        pcall(orig_system, 'true')
        return ''
      end
      gootabs.end_goo('TESTWIN')
      vim.fn.system = orig_system
      -- verify kill-pane commands were attempted for all panes
      local kills = 0
      for _, cmd in ipairs(called) do
        if cmd:find('tmux kill-pane -t', 1, true) then
          kills = kills + 1
        end
      end
      assert.equals(4, kills)
    end)
  end)
end)

describe('gootabs.summon_goo', function()
  local function summon_system_map()
    return {
      ["tmux display-message -p '#{window_name}'"] = "WORK\n",
      ["tmux display-message -p -t %1 '#{window_name}'"] = "TESTWIN\n",
      ["tmux display-message -p -t %2 '#{window_name}'"] = "TESTWIN\n",
      ["tmux display-message -p -t %3 '#{window_name}'"] = "TESTWIN\n",
      ["tmux display-message -p -t %4 '#{window_name}'"] = "TESTWIN\n",
      ["tmux display-message -p '#{socket_path}'"] = "/tmp/tmux-1234/default\n",
      ["tmux select-layout -t TESTWIN even-horizontal"] = "",
    }
  end

  it('configures slime target and joins pane to current window', function()
    -- seed env
    vim.fn.setenv('TESTWIN_1', '%1')
    vim.fn.setenv('TESTWIN_2', '%2')
    vim.fn.setenv('TESTWIN_3', '%3')
    vim.fn.setenv('TESTWIN_4', '%4')

    with_stubbed_system(summon_system_map(), function(executed)
      _G.goo_started = false
      gootabs.summon_goo(2, 'TESTWIN')
      assert.equals('tmux', vim.g.slime_target)
      assert.equals('%2', vim.g.slime_default_config.target_pane)
      assert.is_true(_G.goo_started)
      local join_cmd
      for _, cmd in ipairs(executed) do
        if cmd:find('tmux join-pane', 1, true) then
          join_cmd = cmd
        end
      end
      assert.is_not_nil(join_cmd)
      assert.is_not_nil(join_cmd:match('%-p 33'))
    end)
  end)

  it('honours GOOTABS_JOIN_WIDTH when set to a percentage', function()
    vim.fn.setenv('GOOTABS_JOIN_WIDTH', '55%')
    vim.fn.setenv('TESTWIN_1', '%1')
    vim.fn.setenv('TESTWIN_2', '%2')
    vim.fn.setenv('TESTWIN_3', '%3')
    vim.fn.setenv('TESTWIN_4', '%4')

    with_stubbed_system(summon_system_map(), function(executed)
      gootabs.summon_goo(1, 'TESTWIN')
      local join_cmd
      for _, cmd in ipairs(executed) do
        if cmd:find('tmux join-pane', 1, true) then
          join_cmd = cmd
        end
      end
      assert.is_not_nil(join_cmd)
      assert.is_not_nil(join_cmd:match('%-p 55'))
    end)

    vim.fn.setenv('GOOTABS_JOIN_WIDTH', nil)
  end)

  it('honours GOOTABS_JOIN_WIDTH when set to a fixed size', function()
    vim.fn.setenv('GOOTABS_JOIN_WIDTH', '98')
    vim.fn.setenv('TESTWIN_1', '%1')
    vim.fn.setenv('TESTWIN_2', '%2')
    vim.fn.setenv('TESTWIN_3', '%3')
    vim.fn.setenv('TESTWIN_4', '%4')

    with_stubbed_system(summon_system_map(), function(executed)
      gootabs.summon_goo(3, 'TESTWIN')
      local join_cmd
      for _, cmd in ipairs(executed) do
        if cmd:find('tmux join-pane', 1, true) then
          join_cmd = cmd
        end
      end
      assert.is_not_nil(join_cmd)
      assert.is_not_nil(join_cmd:match('%-l 98'))
    end)

    vim.fn.setenv('GOOTABS_JOIN_WIDTH', nil)
  end)

  it('falls back to the default when GOOTABS_JOIN_WIDTH is invalid', function()
    vim.fn.setenv('GOOTABS_JOIN_WIDTH', '0')
    vim.fn.setenv('TESTWIN_1', '%1')
    vim.fn.setenv('TESTWIN_2', '%2')
    vim.fn.setenv('TESTWIN_3', '%3')
    vim.fn.setenv('TESTWIN_4', '%4')

    with_stubbed_system(summon_system_map(), function(executed)
      gootabs.summon_goo(4, 'TESTWIN')
      local join_cmd
      for _, cmd in ipairs(executed) do
        if cmd:find('tmux join-pane', 1, true) then
          join_cmd = cmd
        end
      end
      assert.is_not_nil(join_cmd)
      assert.is_not_nil(join_cmd:match('%-p 33'))
    end)

    vim.fn.setenv('GOOTABS_JOIN_WIDTH', nil)
  end)
end)

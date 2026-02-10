local config = require("nvim-slimetree.config")
local state = require("nvim-slimetree.state")
local transport = require("nvim-slimetree.core.transport")
local tmux_native = require("nvim-slimetree.core.transport.tmux_native")

describe("core.transport backend resolution", function()
  before_each(function()
    state.config = config.normalize()
    state.reset_transport()
    vim.g.slime_default_config = nil
  end)

  it("uses slime when no tmux target is configured", function()
    local backend = transport.resolve_backend(state.config, 0)
    assert.are.equal("slime", backend)
  end)

  it("uses tmux_native in auto mode when tmux target exists", function()
    vim.g.slime_default_config = {
      socket_name = "default",
      target_pane = "%1",
    }

    local backend = transport.resolve_backend(state.config, 0)
    assert.are.equal("tmux_native", backend)
  end)

  it("falls back to slime when tmux_native is requested but target is missing", function()
    state.config = config.normalize({
      transport = {
        backend = "tmux_native",
      },
    })

    local backend = transport.resolve_backend(state.config, 0)
    assert.are.equal("slime", backend)
  end)
end)

describe("core.transport.tmux_native queue", function()
  local orig_system

  before_each(function()
    orig_system = vim.system
    vim.system = function(_, _, cb)
      vim.schedule(function()
        cb({ code = 0, stdout = "", stderr = "" })
      end)
      return {}
    end

    state.config = config.normalize({
      transport = {
        max_queue = 1,
      },
    })
    state.reset_transport()
    vim.g.slime_default_config = {
      socket_name = "default",
      target_pane = "%1",
    }
  end)

  after_each(function()
    vim.system = orig_system
    state.reset_transport()
    vim.g.slime_default_config = nil
  end)

  it("returns queue_full when async queue limit is reached", function()
    local first = tmux_native.send("cat('a')", {
      bufnr = 0,
      async = true,
      transport_cfg = state.config.transport,
    })

    local second = tmux_native.send("cat('b')", {
      bufnr = 0,
      async = true,
      transport_cfg = state.config.transport,
    })

    assert.is_true(first.ok)
    assert.is_false(second.ok)
    assert.are.equal("transport_queue_full", second.reason)
  end)
end)

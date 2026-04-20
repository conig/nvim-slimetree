local config = require("nvim-slimetree.config")
local state = require("nvim-slimetree.state")
local transport = require("nvim-slimetree.core.transport")
local terminal = require("nvim-slimetree.core.transport.terminal")
local tmux_native = require("nvim-slimetree.core.transport.tmux_native")

describe("core.transport backend resolution", function()
  before_each(function()
    state.config = config.normalize()
    state.reset_transport()
    vim.g.slimetree_terminal_config = nil
    vim.g.slime_target = nil
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

  it("uses terminal in auto mode when a managed terminal target exists", function()
    vim.g.slimetree_terminal_config = {
      jobid = 17,
    }

    local backend = transport.resolve_backend(state.config, 0)
    assert.are.equal("terminal", backend)
  end)

  it("prefers tmux_native over terminal in auto mode", function()
    vim.g.slime_default_config = {
      socket_name = "default",
      target_pane = "%1",
    }
    vim.g.slimetree_terminal_config = {
      jobid = 17,
    }

    local backend = transport.resolve_backend(state.config, 0)
    assert.are.equal("tmux_native", backend)
  end)

  it("reuses slime neovim config as a terminal target", function()
    vim.g.slime_target = "neovim"
    vim.g.slime_default_config = {
      jobid = 23,
    }

    local backend = transport.resolve_backend(state.config, 0)
    assert.are.equal("terminal", backend)
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

  it("falls back to slime when terminal is requested but target is missing", function()
    state.config = config.normalize({
      transport = {
        backend = "terminal",
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

describe("core.transport.terminal", function()
  local orig_chan_send
  local term_bufnr
  local term_jobid

  local function create_terminal()
    local prev_buf = vim.api.nvim_get_current_buf()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    local jobid = vim.fn.termopen({ "cat" })
    vim.api.nvim_set_current_buf(prev_buf)
    vim.wait(1000, function()
      return tonumber(vim.fn.getbufvar(bufnr, "&channel")) == jobid
    end, 10)
    return bufnr, jobid
  end

  before_each(function()
    orig_chan_send = vim.api.nvim_chan_send
    vim.g.slimetree_terminal_config = nil
    vim.g.slime_target = nil
    vim.g.slime_default_config = nil
    state.config = config.normalize({
      transport = {
        backend = "terminal",
      },
    })
    state.reset_transport()
  end)

  after_each(function()
    vim.api.nvim_chan_send = orig_chan_send
    vim.g.slimetree_terminal_config = nil
    vim.g.slime_target = nil
    vim.g.slime_default_config = nil
    if term_jobid then
      pcall(vim.fn.jobstop, term_jobid)
    end
    if term_bufnr and vim.api.nvim_buf_is_valid(term_bufnr) then
      pcall(vim.api.nvim_buf_delete, term_bufnr, { force = true })
    end
    term_bufnr = nil
    term_jobid = nil
    state.reset_transport()
  end)

  it("derives a terminal job from a configured terminal buffer", function()
    term_bufnr, term_jobid = create_terminal()
    vim.g.slimetree_terminal_config = {
      bufnr = term_bufnr,
    }

    local target = terminal.resolve_target(0)

    assert.are.same({
      bufnr = term_bufnr,
      jobid = term_jobid,
    }, target)
  end)

  it("sends bracketed paste payloads to the configured terminal job", function()
    term_bufnr, term_jobid = create_terminal()
    vim.g.slimetree_terminal_config = {
      jobid = term_jobid,
    }
    state.config = config.normalize({
      transport = {
        backend = "terminal",
        terminal = {
          bracketed_paste = true,
        },
      },
    })

    local sent = {}
    vim.api.nvim_chan_send = function(jobid, payload)
      sent.jobid = jobid
      sent.payload = payload
    end

    local result = terminal.send("x <- 1", {
      bufnr = 0,
      transport_cfg = state.config.transport,
    })

    assert.is_true(result.ok)
    assert.are.equal("terminal", result.backend)
    assert.are.equal(term_jobid, sent.jobid)
    assert.are.equal("\27[200~x <- 1\27[201~\n", sent.payload)
    assert.are.equal(1, state.transport.stats.sent)
  end)
end)

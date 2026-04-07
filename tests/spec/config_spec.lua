local config = require("nvim-slimetree.config")

describe("config.normalize", function()
  it("keeps gootabs disabled by default", function()
    local cfg = config.normalize()
    assert.is_false(cfg.gootabs.enabled)
  end)

  it("derives pane_count from single layout", function()
    local cfg = config.normalize({
      gootabs = { layout = "single", pane_count = 9 },
    })

    assert.are.equal(1, cfg.gootabs.pane_count)
  end)

  it("derives pane_count from custom commands", function()
    local cfg = config.normalize({
      gootabs = {
        layout = "custom",
        pane_commands = { "R", "python" },
      },
    })

    assert.are.equal(2, cfg.gootabs.pane_count)
  end)

  it("includes default aliases for python and common shell filetypes", function()
    local cfg = config.normalize()
    assert.are.equal("python", cfg.language_aliases.python)
    assert.are.equal("bash", cfg.language_aliases.sh)
    assert.are.equal("bash", cfg.language_aliases.bash)
    assert.are.equal("bash", cfg.language_aliases.zsh)
    assert.are.equal("bash", cfg.language_aliases.ksh)
  end)

  it("uses transport defaults for async tmux-native auto mode", function()
    local cfg = config.normalize()
    assert.are.equal("auto", cfg.transport.backend)
    assert.is_true(cfg.transport.async)
    assert.are.equal(256, cfg.transport.max_queue)
    assert.is_true(cfg.transport.fallback_to_slime)
    assert.are.equal("slimetree_send", cfg.transport.tmux.buffer_name)
  end)

  it("normalizes invalid transport fields to safe defaults", function()
    local cfg = config.normalize({
      transport = {
        backend = "wat",
        mode = "bad",
        max_queue = -9,
        tmux = {
          bracketed_paste = "bad",
          enter_mode = "bad",
          buffer_name = "",
        },
      },
    })

    assert.are.equal("auto", cfg.transport.backend)
    assert.are.equal("control", cfg.transport.mode)
    assert.are.equal(1, cfg.transport.max_queue)
    assert.are.equal("auto", cfg.transport.tmux.bracketed_paste)
    assert.are.equal("auto", cfg.transport.tmux.enter_mode)
    assert.are.equal("slimetree_send", cfg.transport.tmux.buffer_name)
  end)
end)

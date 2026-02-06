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
end)

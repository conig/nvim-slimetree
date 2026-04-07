local config = require("nvim-slimetree.config")
local lang = require("nvim-slimetree.core.lang")

describe("core.lang.resolve_for_filetype", function()
  before_each(function()
    lang.clear_cache()
  end)

  it("resolves known filetype aliases", function()
    local cfg = config.normalize()
    local r_spec, r_err = lang.resolve_for_filetype("r", cfg)
    assert.is_nil(r_err)
    assert.is_table(r_spec)
    assert.is_true(r_spec.acceptable.call == true)

    local py_spec, py_err = lang.resolve_for_filetype("python", cfg)
    assert.is_nil(py_err)
    assert.is_table(py_spec)
    assert.is_true(py_spec.acceptable.expression_statement == true)

    for _, ft in ipairs({ "sh", "bash", "zsh", "ksh" }) do
      local shell_spec, shell_err = lang.resolve_for_filetype(ft, cfg)
      assert.is_nil(shell_err)
      assert.is_table(shell_spec)
      assert.is_true(shell_spec.root.program == true)
      assert.is_true(shell_spec.acceptable.command == true)
    end
  end)

  it("returns unsupported_filetype for unknown filetype", function()
    local cfg = config.normalize()
    local spec, err = lang.resolve_for_filetype("ruby", cfg)
    assert.is_nil(spec)
    assert.are.equal("unsupported_filetype", err)
  end)
end)

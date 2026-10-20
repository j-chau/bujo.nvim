local config = require("bujo.config")

describe("config.setup", function()
  after_each(function()
    config.setup()
  end)

  it("uses defaults when called without options", function()
    config.setup()
    assert.are.same(config.defaults, config.options)
  end)

  it("deep-merges user options over defaults", function()
    config.setup({ side_days = 3, keymaps = { complete = "X" } })
    assert.are.equal(3, config.options.side_days)
    assert.are.equal("X", config.options.keymaps.complete)
    assert.are.equal("c", config.options.keymaps.cancel)
  end)

  it("does not mutate the defaults table", function()
    config.setup({ float = { width = 10 } })
    assert.are.equal(60, config.defaults.float.width)
  end)
end)

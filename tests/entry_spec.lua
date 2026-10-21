local entry = require("bujo.entry")

local function e(kind, state)
  return { kind = kind, state = state, text = "x" }
end

describe("entry", function()
  it("new creates an open entry", function()
    assert.are.same({ kind = "note", state = "open", text = "hi" }, entry.new("note", "hi"))
  end)

  it("glyph follows task state and keeps the open glyph when cancelled", function()
    assert.are.equal("•", entry.glyph(e("task", "open")))
    assert.are.equal("×", entry.glyph(e("task", "done")))
    assert.are.equal("›", entry.glyph(e("task", "migrated")))
    assert.are.equal("•", entry.glyph(e("task", "cancelled")))
    assert.are.equal("–", entry.glyph(e("note", "open")))
    assert.are.equal("▽", entry.glyph(e("event", "cancelled")))
    assert.are.equal("▷", entry.glyph(e("future", "open")))
  end)

  describe("can", function()
    it("lets open tasks complete, migrate and cancel", function()
      for _, action in ipairs({ "complete", "migrate", "cancel" }) do
        assert.is_true(entry.can(e("task", "open"), action), action)
      end
      assert.is_false(entry.can(e("task", "open"), "reopen"))
    end)

    it("lets events only be cancelled", function()
      for _, kind in ipairs({ "event", "future" }) do
        assert.is_true(entry.can(e(kind, "open"), "cancel"))
        assert.is_false(entry.can(e(kind, "open"), "complete"))
        assert.is_false(entry.can(e(kind, "open"), "migrate"))
      end
    end)

    it("gives notes and raw lines no status changes", function()
      for _, kind in ipairs({ "note", "raw" }) do
        for _, action in ipairs({ "complete", "migrate", "cancel", "reopen" }) do
          assert.is_false(entry.can(e(kind, "open"), action), kind .. " " .. action)
        end
      end
    end)

    it("requires reopening before changing a non-open entry", function()
      for _, state in ipairs({ "done", "migrated", "cancelled" }) do
        assert.is_false(entry.can(e("task", state), "complete"))
        assert.is_false(entry.can(e("task", state), "cancel"))
        assert.is_true(entry.can(e("task", state), "reopen"))
      end
      assert.is_true(entry.can(e("event", "cancelled"), "reopen"))
    end)
  end)

  describe("apply", function()
    it("returns a new entry in the target state", function()
      local open = e("task", "open")
      assert.are.same(e("task", "done"), entry.apply(open, "complete"))
      assert.are.same(e("task", "migrated"), entry.apply(open, "migrate"))
      assert.are.same(e("task", "cancelled"), entry.apply(open, "cancel"))
      assert.are.same(e("task", "open"), entry.apply(e("task", "done"), "reopen"))
      assert.are.equal("open", open.state)
    end)

    it("returns nil for disallowed actions", function()
      assert.is_nil(entry.apply(e("note", "open"), "cancel"))
      assert.is_nil(entry.apply(e("task", "done"), "migrate"))
    end)
  end)
end)

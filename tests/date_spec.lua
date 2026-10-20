local date = require("bujo.date")

describe("date", function()
  local real_now = date.now

  after_each(function()
    date.now = real_now
  end)

  describe("parse", function()
    it("parses ISO dates", function()
      assert.are.same({ year = 2026, month = 10, day = 20 }, date.parse("2026-10-20"))
    end)

    it("rejects malformed and impossible dates", function()
      assert.is_nil(date.parse("2026-1-20"))
      assert.is_nil(date.parse("20-10-2026"))
      assert.is_nil(date.parse("2026-02-30"))
      assert.is_nil(date.parse("2026-13-01"))
      assert.is_nil(date.parse(""))
    end)

    it("accepts leap days only in leap years", function()
      assert.is_true(date.is_valid("2028-02-29"))
      assert.is_false(date.is_valid("2026-02-29"))
    end)
  end)

  it("today uses the overridable clock", function()
    date.now = function()
      return os.time({ year = 2026, month = 10, day = 20, hour = 23, min = 59 })
    end
    assert.are.equal("2026-10-20", date.today())
  end)

  describe("add_days", function()
    it("moves forwards and backwards", function()
      assert.are.equal("2026-10-21", date.add_days("2026-10-20", 1))
      assert.are.equal("2026-10-13", date.add_days("2026-10-20", -7))
      assert.are.equal("2026-10-20", date.add_days("2026-10-20", 0))
    end)

    it("rolls over months and years", function()
      assert.are.equal("2026-11-01", date.add_days("2026-10-31", 1))
      assert.are.equal("2027-01-01", date.add_days("2026-12-31", 1))
      assert.are.equal("2025-12-31", date.add_days("2026-01-01", -1))
      assert.are.equal("2028-02-29", date.add_days("2028-02-28", 1))
    end)

    it("is not thrown off by DST transitions", function()
      -- Spans both the March and November transitions used in most regions.
      assert.are.equal("2026-03-30", date.add_days("2026-03-01", 29))
      assert.are.equal("2026-11-02", date.add_days("2026-10-31", 2))
    end)
  end)

  describe("diff_days", function()
    it("counts whole days between dates", function()
      assert.are.equal(1, date.diff_days("2026-10-20", "2026-10-21"))
      assert.are.equal(-7, date.diff_days("2026-10-20", "2026-10-13"))
      assert.are.equal(365, date.diff_days("2026-01-01", "2027-01-01"))
      assert.are.equal(0, date.diff_days("2026-10-20", "2026-10-20"))
    end)
  end)

  describe("header", function()
    it("stretches dashes so the lowercase weekday ends at width", function()
      local h = date.header("2026-10-20", 40)
      assert.are.equal(40, #h)
      assert.are.equal("2026-10-20 " .. string.rep("-", 21) .. " tuesday", h)
      assert.are.equal("2027-01-01 " .. string.rep("-", 20) .. " friday", date.header("2027-01-01", 38))
    end)

    it("keeps at least 3 dashes when the width is too narrow", function()
      assert.are.equal("2026-10-20 --- tuesday", date.header("2026-10-20", 5))
    end)
  end)
end)

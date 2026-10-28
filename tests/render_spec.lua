local entry = require("bujo.entry")
local parser = require("bujo.parser")
local render = require("bujo.render")

local WIDTH = 30

local function section(day, content)
  return render.day_section(day, parser.parse(content))
end

local function marks_on(rendered, row)
  return vim.tbl_filter(function(m)
    return m.row == row
  end, rendered.marks)
end

describe("render", function()
  describe("build", function()
    it("renders a header, the file lines and a blank line between days", function()
      local r = render.build({
        section("2026-10-19", "• a\n"),
        section("2026-10-20", "× b\n– c\n"),
      }, WIDTH)
      assert.are.same({
        "2026-10-19 " .. string.rep("-", 12) .. " monday",
        "• a",
        "",
        "2026-10-20 " .. string.rep("-", 11) .. " tuesday",
        "× b",
        "– c",
      }, r.lines)
    end)

    it("stretches headers to the given width", function()
      local r = render.build({ section("2026-10-20", "• a\n") }, 40)
      assert.are.equal(40, #r.lines[1])
    end)

    it("maps entry lines to their day, index and entry", function()
      local r = render.build({
        section("2026-10-19", "• a\n"),
        section("2026-10-20", "× b\n– c\n"),
      }, WIDTH)
      assert.are.same({ day = "2026-10-19" }, r.linemap[1])
      assert.are.same({ day = "2026-10-19", index = 1, entry = entry.new("task", "a") }, r.linemap[2])
      assert.are.same({ day = "2026-10-20" }, r.linemap[3])
      assert.are.same({ day = "2026-10-20" }, r.linemap[4])
      assert.are.equal(2, r.linemap[6].index)
      assert.are.equal("note", r.linemap[6].entry.kind)
    end)

    it("keeps each item's original index when only some are shown", function()
      local entries = parser.parse("× done\n• open\n")
      local r = render.build({ { day = "2026-10-08", items = { { index = 2, entry = entries[2] } } } }, WIDTH)
      assert.are.same({ "2026-10-08 " .. string.rep("-", 10) .. " thursday", "• open" }, r.lines)
      assert.are.equal(2, r.linemap[2].index)
    end)

    it("shows an empty state for blank days", function()
      for _, content in ipairs({ "", "\n\n", "  \n" }) do
        local r = render.build({ section("2026-10-20", content) }, WIDTH)
        assert.are.same({ "2026-10-20 " .. string.rep("-", 11) .. " tuesday", render.EMPTY }, r.lines)
        assert.are.same({ day = "2026-10-20" }, r.linemap[2])
        assert.are.equal("BujoEmpty", marks_on(r, 1)[1].hl)
      end
    end)

    it("highlights the header and its rule", function()
      local r = render.build({ section("2026-10-20", "• a\n") }, WIDTH)
      assert.are.same({
        { row = 0, col = 0, end_col = WIDTH, hl = "BujoHeader" },
        { row = 0, col = 11, end_col = 22, hl = "BujoRule" },
      }, marks_on(r, 0))
    end)

    it("highlights entries by state using byte offsets", function()
      local r = render.build({ section("2026-10-20", "• a\n× b\n› c\n~• d\n▽ e\nfree\n") }, WIDTH)
      assert.are.same({ { row = 1, col = 0, end_col = #"•", hl = "BujoGlyph" } }, marks_on(r, 1))
      assert.are.same({ { row = 2, col = 0, end_col = #"× b", hl = "BujoDone" } }, marks_on(r, 2))
      assert.are.same({ { row = 3, col = 0, end_col = #"› c", hl = "BujoDone" } }, marks_on(r, 3))
      assert.are.same({
        { row = 4, col = 0, end_col = 1, conceal = true },
        { row = 4, col = 1, end_col = #"~• d", hl = "BujoCancelled" },
      }, marks_on(r, 4))
      assert.are.same({ { row = 5, col = 0, end_col = #"▽", hl = "BujoGlyph" } }, marks_on(r, 5))
      assert.are.same({ { row = 6, col = 0, end_col = 4, hl = "BujoRaw" } }, marks_on(r, 6))
    end)
  end)

  describe("apply", function()
    local buf

    before_each(function()
      buf = vim.api.nvim_create_buf(false, true)
    end)

    after_each(function()
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("sets lines and extmarks and leaves the buffer read-only", function()
      local r = render.build({ section("2026-10-20", "• a\n~• b\n") }, WIDTH)
      render.apply(buf, r)
      assert.are.same(r.lines, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      assert.is_false(vim.bo[buf].modifiable)
      local marks = vim.api.nvim_buf_get_extmarks(buf, render.ns, 0, -1, { details = true })
      assert.are.equal(#r.marks, #marks)
      local cancelled = vim.tbl_filter(function(m)
        return m[4].conceal == ""
      end, marks)
      assert.are.equal(1, #cancelled)
    end)

    it("replaces previous lines and marks on re-render", function()
      render.apply(buf, render.build({ section("2026-10-20", "• a\n• b\n• c\n") }, WIDTH))
      local r = render.build({ section("2026-10-20", "• a\n") }, WIDTH)
      render.apply(buf, r)
      assert.are.same(r.lines, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      assert.are.equal(#r.marks, #vim.api.nvim_buf_get_extmarks(buf, render.ns, 0, -1, {}))
    end)

    it("defines a strikethrough highlight for cancelled entries", function()
      render.apply(buf, render.build({}, WIDTH))
      assert.is_true(vim.api.nvim_get_hl(0, { name = "BujoCancelled" }).strikethrough)
      assert.are.equal("Title", vim.api.nvim_get_hl(0, { name = "BujoHeader" }).link)
    end)
  end)
end)

local actions = require("bujo.actions")
local config = require("bujo.config")
local date = require("bujo.date")
local entry = require("bujo.entry")
local store = require("bujo.store")

local TODAY = "2026-10-20"
local TOMORROW = "2026-10-21"

local function read_file(iso)
  local f = io.open(store.path_for(iso), "rb")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

local function task(text, state)
  return { kind = "task", state = state or "open", text = text }
end

describe("actions", function()
  local dir
  local real_now = date.now

  before_each(function()
    dir = vim.fn.tempname()
    config.setup({ data_dir = dir })
    store.clear_cache()
    date.now = function()
      return os.time({ year = 2026, month = 10, day = 20, hour = 9 })
    end
  end)

  after_each(function()
    date.now = real_now
    vim.fn.delete(dir, "rf")
    config.setup()
  end)

  describe("status changes", function()
    before_each(function()
      store.write_day(TODAY, { task("a"), entry.new("event", "standup"), entry.new("note", "n") })
    end)

    it("completes a task", function()
      assert.is_true(actions.complete(TODAY, 1, task("a")))
      assert.are.equal("× a\n▽ standup\n– n\n", read_file(TODAY))
    end)

    it("cancels a task and an event", function()
      assert.is_true(actions.cancel(TODAY, 1, task("a")))
      assert.is_true(actions.cancel(TODAY, 2, entry.new("event", "standup")))
      assert.are.equal("~• a\n~▽ standup\n– n\n", read_file(TODAY))
    end)

    it("reopens a changed entry", function()
      actions.complete(TODAY, 1, task("a"))
      assert.is_true(actions.reopen(TODAY, 1, task("a", "done")))
      assert.are.equal("• a\n▽ standup\n– n\n", read_file(TODAY))
    end)

    it("refuses disallowed changes without writing", function()
      local ok, err = actions.cancel(TODAY, 3, entry.new("note", "n"))
      assert.is_false(ok)
      assert.are.equal("can't cancel this entry", err)
      assert.are.equal("• a\n▽ standup\n– n\n", read_file(TODAY))
    end)

    it("refuses when the entry no longer matches", function()
      local ok, err = actions.complete(TODAY, 1, task("something else"))
      assert.is_false(ok)
      assert.matches("changed on disk", err)
      assert.is_false((actions.complete(TODAY, 9, task("a"))))
      assert.are.equal("• a\n▽ standup\n– n\n", read_file(TODAY))
    end)
  end)

  describe("migrate", function()
    it("adds the task to a new file for tomorrow", function()
      store.write_day(TODAY, { task("fix bike") })
      assert.is_true(actions.migrate(TODAY, 1, task("fix bike")))
      assert.are.equal("› fix bike\n", read_file(TODAY))
      assert.are.equal("• fix bike\n", read_file(TOMORROW))
    end)

    it("appends to tomorrow's existing file", function()
      store.write_day(TODAY, { task("fix bike") })
      store.write_day(TOMORROW, { entry.new("event", "dentist") })
      assert.is_true(actions.migrate(TODAY, 1, task("fix bike")))
      assert.are.equal("▽ dentist\n• fix bike\n", read_file(TOMORROW))
    end)

    it("moves tasks from earlier days to today", function()
      store.write_day("2026-10-08", { task("old") })
      store.write_day(TODAY, { entry.new("note", "n") })
      assert.is_true(actions.migrate("2026-10-08", 1, task("old")))
      assert.are.equal("› old\n", read_file("2026-10-08"))
      assert.are.equal("– n\n• old\n", read_file(TODAY))
      assert.is_nil(read_file("2026-10-09"))
      assert.is_nil(read_file(TOMORROW))
    end)

    it("only migrates open tasks", function()
      store.write_day(TODAY, { task("done", "done"), entry.new("event", "e") })
      assert.is_false((actions.migrate(TODAY, 1, task("done", "done"))))
      assert.is_false((actions.migrate(TODAY, 2, entry.new("event", "e"))))
      assert.is_nil(read_file(TOMORROW))
    end)

    it("refuses tasks on future days", function()
      store.write_day(TOMORROW, { task("a") })
      local ok, err = actions.migrate(TOMORROW, 1, task("a"))
      assert.is_false(ok)
      assert.are.equal("can't migrate a task from a future day", err)
      assert.are.equal("• a\n", read_file(TOMORROW))
      assert.is_nil(read_file(TODAY))
    end)
  end)

  describe("add", function()
    it("appends trimmed entries to today, creating the file", function()
      assert.is_true(actions.add("task", "  buy milk  "))
      assert.is_true(actions.add("future", "dentist next tue"))
      assert.are.equal("• buy milk\n▷ dentist next tue\n", read_file(TODAY))
    end)

    it("ignores empty text and creates no file", function()
      assert.is_false((actions.add("note", "   ")))
      assert.is_false((actions.add("note", nil)))
      assert.is_nil(read_file(TODAY))
    end)
  end)
end)

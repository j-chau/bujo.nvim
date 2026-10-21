local config = require("bujo.config")
local entry = require("bujo.entry")
local store = require("bujo.store")

local function write_file(path, content)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local f = assert(io.open(path, "wb"))
  f:write(content)
  f:close()
end

local function read_file(path)
  local f = assert(io.open(path, "rb"))
  local content = f:read("*a")
  f:close()
  return content
end

describe("store", function()
  local dir

  before_each(function()
    dir = vim.fn.tempname()
    config.setup({ data_dir = dir })
    store.clear_cache()
  end)

  after_each(function()
    vim.fn.delete(dir, "rf")
    config.setup()
  end)

  it("lays out files by year", function()
    assert.are.equal(dir .. "/2026/2026-10-20.md", store.path_for("2026-10-20"))
  end)

  it("reads a missing day as empty", function()
    assert.are.same({}, store.read_day("2026-10-20"))
  end)

  it("writes LF files and reads them back", function()
    store.write_day("2026-10-20", { entry.new("task", "buy milk"), entry.new("note", "hi") })
    assert.are.equal("• buy milk\n– hi\n", read_file(store.path_for("2026-10-20")))
    store.clear_cache()
    assert.are.same(
      { entry.new("task", "buy milk"), entry.new("note", "hi") },
      store.read_day("2026-10-20")
    )
  end)

  it("overwrites an existing day and leaves no temp file", function()
    store.write_day("2026-10-20", { entry.new("task", "a") })
    store.write_day("2026-10-20", { entry.new("task", "b") })
    assert.are.equal("• b\n", read_file(store.path_for("2026-10-20")))
    assert.is_nil(vim.uv.fs_stat(store.path_for("2026-10-20") .. ".tmp"))
  end)

  it("removes the file when a day is written empty", function()
    store.write_day("2026-10-20", { entry.new("task", "a") })
    store.write_day("2026-10-20", {})
    assert.is_nil(vim.uv.fs_stat(store.path_for("2026-10-20")))
    assert.are.same({}, store.read_day("2026-10-20"))
  end)

  it("returns copies so callers can't corrupt the cache", function()
    store.write_day("2026-10-20", { entry.new("task", "a") })
    store.read_day("2026-10-20")[1].text = "changed"
    assert.are.equal("a", store.read_day("2026-10-20")[1].text)
  end)

  it("picks up edits made outside the plugin", function()
    store.write_day("2026-10-20", { entry.new("task", "a") })
    assert.are.equal("a", store.read_day("2026-10-20")[1].text)
    write_file(store.path_for("2026-10-20"), "× edited by hand\n")
    assert.are.same({ { kind = "task", state = "done", text = "edited by hand" } }, store.read_day("2026-10-20"))
  end)

  it("lists days oldest first and ignores other files", function()
    write_file(dir .. "/2026/2026-10-20.md", "• a\n")
    write_file(dir .. "/2025/2025-12-31.md", "• b\n")
    write_file(dir .. "/2026/2026-01-05.md", "• c\n")
    write_file(dir .. "/2026/notes.md", "x\n")
    write_file(dir .. "/2026/2026-10-21.md.tmp", "x\n")
    write_file(dir .. "/2026-10-22.md", "x\n")
    assert.are.same({ "2025-12-31", "2026-01-05", "2026-10-20" }, store.list_days())
  end)

  it("lists nothing when the data dir doesn't exist", function()
    assert.are.same({}, store.list_days())
  end)

  describe("previous_day", function()
    it("finds the latest earlier day with a file, even a blank one", function()
      write_file(dir .. "/2026/2026-10-14.md", "• old\n")
      write_file(dir .. "/2026/2026-10-16.md", "– friday\n")
      write_file(dir .. "/2026/2026-10-18.md", "")
      write_file(dir .. "/2026/2026-10-20.md", "• today\n")
      write_file(dir .. "/2026/2026-10-21.md", "• future\n")
      assert.are.equal("2026-10-18", store.previous_day("2026-10-20"))
    end)

    it("returns nil when there is no earlier day", function()
      write_file(dir .. "/2026/2026-10-20.md", "• today\n")
      assert.is_nil(store.previous_day("2026-10-20"))
    end)
  end)
end)

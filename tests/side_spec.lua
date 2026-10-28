local config = require("bujo.config")
local date = require("bujo.date")
local side = require("bujo.ui.side")
local store = require("bujo.store")

local TODAY = "2026-10-20"

local function write_file(iso, content)
  local path = store.path_for(iso)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local f = assert(io.open(path, "wb"))
  f:write(content)
  f:close()
end

local function read_file(iso)
  local f = io.open(store.path_for(iso), "rb")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

-- Six earlier days with files, skipping weekends, so the full range spans
-- more than 7 calendar days and anything before 2026-10-09 is older.
local function write_week()
  for _, day in ipairs({ "2026-10-09", "2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15", "2026-10-16" }) do
    write_file(day, "– " .. day .. "\n")
  end
end

local function side_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf):find("bujo://side", 1, true) then
      return buf
    end
  end
end

local function side_lines()
  return vim.api.nvim_buf_get_lines(side_buf(), 0, -1, false)
end

local function headers(lines)
  local days = {}
  for _, line in ipairs(lines) do
    local day = line:match("^(%d%d%d%d%-%d%d%-%d%d) %-")
    if day then
      table.insert(days, day)
    end
  end
  return days
end

local function cursor_to(text)
  for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line == text then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      return
    end
  end
  error("line not found: " .. text)
end

describe("side panel", function()
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
    vim.cmd("silent! only")
    vim.cmd("silent! %bwipeout!")
    vim.fn.delete(dir, "rf")
    config.setup()
  end)

  describe("sections", function()
    local function days(sections)
      return vim.tbl_map(function(s)
        return s.day
      end, sections)
    end

    it("shows the last 7 days with a file in full, oldest first", function()
      write_week()
      write_file(TODAY, "• today\n")
      local sections = side.sections()
      assert.are.same(
        { "2026-10-09", "2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15", "2026-10-16", TODAY },
        days(sections)
      )
      assert.are.equal(1, #sections[1].items)
    end)

    it("always includes today, even without a file", function()
      write_file("2026-10-16", "• friday\n")
      assert.are.same({ "2026-10-16", TODAY }, days(side.sections()))
    end)

    it("includes blank files", function()
      write_file("2026-10-18", "")
      local sections = side.sections()
      assert.are.same({ "2026-10-18", TODAY }, days(sections))
      assert.are.equal(0, #sections[1].items)
    end)

    it("adds open tasks from older days above, keeping their indexes", function()
      write_file("2026-10-01", "× done\n– note\n")
      write_file("2026-10-05", "× done\n• still open\n▽ event\n~• cancelled\n• also open\n")
      write_file("2026-10-08", "• day before range\n")
      write_week()
      local sections = side.sections()
      assert.are.same({ "2026-10-05", "2026-10-08", "2026-10-09" }, vim.list_slice(days(sections), 1, 3))
      assert.are.same({ 2, 5 }, vim.tbl_map(function(item)
        return item.index
      end, sections[1].items))
      assert.are.equal(9, #sections)
    end)

    it("only looks back side_lookback_days for open tasks", function()
      write_file("2026-09-19", "• 31 days ago\n")
      write_file("2026-09-20", "• 30 days ago\n")
      write_week()
      local sections = side.sections()
      assert.are.equal("2026-09-20", sections[1].day)
      assert.are.equal(8, #sections)
    end)

    it("shows no older tasks unless side_lookback_days is a positive integer", function()
      write_file("2026-10-05", "• old\n")
      write_week()
      for _, value in ipairs({ 0, -5, 3.5, "30", false, true, {} }) do
        config.setup({ data_dir = dir, side_lookback_days = value })
        local sections = side.sections()
        assert.are.equal(7, #sections, vim.inspect(value))
        assert.are.equal("2026-10-09", sections[1].day, vim.inspect(value))
      end
    end)

    it("ignores days after today", function()
      write_file("2026-10-21", "• tomorrow\n")
      assert.are.same({ TODAY }, days(side.sections()))
    end)

    it("respects side_days", function()
      config.setup({ data_dir = dir, side_days = 3 })
      write_file("2026-10-07", "• open\n")
      write_week()
      assert.are.same({ "2026-10-07", "2026-10-15", "2026-10-16", TODAY }, days(side.sections()))
    end)
  end)

  it("opens a fixed-width split on the right scrolled to the bottom", function()
    write_file("2026-10-05", "• old\n")
    write_week()
    write_file(TODAY, "• today\n")
    local main = vim.api.nvim_get_current_win()
    vim.cmd("Bujo side")
    local win = vim.api.nvim_get_current_win()
    assert.are_not.equal(main, win)
    assert.are.equal("", vim.api.nvim_win_get_config(win).relative)
    assert.are.equal(config.options.side_width, vim.api.nvim_win_get_width(win))
    assert.is_true(vim.wo[win].winfixwidth)
    assert.is_true(vim.api.nvim_win_get_position(win)[2] > vim.api.nvim_win_get_position(main)[2])
    assert.are.equal("• today", vim.api.nvim_get_current_line())
    assert.are.equal(#side_lines(), vim.api.nvim_win_get_cursor(win)[1])
    assert.are.equal(8, #headers(side_lines()))
  end)

  it("toggles closed", function()
    vim.cmd("Bujo side")
    vim.cmd("Bujo side")
    assert.are.equal(1, #vim.api.nvim_list_wins())
    assert.is_nil(side_buf())
  end)

  it("changes old tasks, which then drop out of the panel", function()
    write_file("2026-10-08", "× done\n• old task\n")
    write_week()
    vim.cmd("Bujo side")
    cursor_to("• old task")
    vim.api.nvim_feedkeys("x", "x", false)
    assert.are.equal("× done\n× old task\n", read_file("2026-10-08"))
    assert.are.same({}, vim.tbl_filter(function(d)
      return d == "2026-10-08"
    end, headers(side_lines())))
  end)

  it("migrates old tasks onto today", function()
    write_file("2026-10-08", "• old task\n")
    write_week()
    vim.cmd("Bujo side")
    cursor_to("• old task")
    vim.api.nvim_feedkeys("m", "x", false)
    assert.are.equal("› old task\n", read_file("2026-10-08"))
    assert.are.equal("• old task", side_lines()[#side_lines()])
  end)

  it("adds new entries to today", function()
    vim.cmd("Bujo side")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local real_input = vim.ui.input
    vim.ui.input = function(_, cb)
      cb("new note")
    end
    vim.api.nvim_feedkeys("n", "x", false)
    vim.ui.input = real_input
    assert.are.equal("– new note\n", read_file(TODAY))
    assert.are.equal("– new note", side_lines()[#side_lines()])
  end)

  it("stays open when opening a day file", function()
    write_file("2026-10-15", "• a\n")
    vim.cmd("Bujo side")
    cursor_to("• a")
    vim.api.nvim_feedkeys("gf", "x", false)
    assert.is_not_nil(side_buf())
    assert.are.equal(1, #vim.fn.win_findbuf(side_buf()))
    assert.are.equal(vim.fs.normalize(store.path_for("2026-10-15")), vim.fs.normalize(vim.api.nvim_buf_get_name(0)))
  end)

  it("is refreshed by changes made in the today float", function()
    write_file(TODAY, "• shared\n")
    vim.cmd("Bujo side")
    vim.cmd("wincmd p")
    vim.cmd("Bujo")
    cursor_to("• shared")
    vim.api.nvim_feedkeys("x", "x", false)
    assert.are.equal("× shared", side_lines()[#side_lines()])
  end)
end)

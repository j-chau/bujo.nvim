local config = require("bujo.config")
local date = require("bujo.date")
local float = require("bujo.ui.float")
local store = require("bujo.store")

local TODAY = "2026-10-20"

local function write_file(iso, content)
  local path = store.path_for(iso)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local f = assert(io.open(path, "wb"))
  f:write(content)
  f:close()
end

local function floats()
  return vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative ~= ""
  end, vim.api.nvim_list_wins())
end

local function buf_named(name)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf):find(name, 1, true) then
      return buf
    end
  end
end

local function page_lines(name)
  return vim.api.nvim_buf_get_lines(buf_named(name), 0, -1, false)
end

local function page_win(name)
  return vim.fn.win_findbuf(buf_named(name))[1]
end

describe("spread", function()
  local dir
  local real_now = date.now
  local columns, lines = vim.o.columns, vim.o.lines

  before_each(function()
    dir = vim.fn.tempname()
    config.setup({ data_dir = dir })
    store.clear_cache()
    date.now = function()
      return os.time({ year = 2026, month = 10, day = 20, hour = 9 })
    end
    vim.o.columns, vim.o.lines = 160, 50
  end)

  after_each(function()
    date.now = real_now
    for _, win in ipairs(floats()) do
      pcall(vim.api.nvim_win_close, win, true)
    end
    vim.cmd("silent! %bwipeout!")
    vim.o.columns, vim.o.lines = columns, lines
    vim.fn.delete(dir, "rf")
    config.setup()
  end)

  describe("previous_day", function()
    it("is the latest earlier day with a file", function()
      write_file("2026-10-16", "• friday\n")
      write_file("2026-10-14", "• older\n")
      assert.are.equal("2026-10-16", float.previous_day())
    end)

    it("falls back to the calendar day before", function()
      assert.are.equal("2026-10-19", float.previous_day())
    end)
  end)

  it("opens the previous day and today side by side, focused on today", function()
    write_file("2026-10-16", "• friday task\n")
    write_file(TODAY, "• a\n– b\n")
    vim.cmd("Bujo spread")
    assert.are.equal(2, #floats())

    local previous = page_lines("spread/previous")
    assert.matches("^2026%-10%-16 .* friday$", previous[1])
    assert.are.equal("• friday task", previous[2])
    assert.are.same({ "• a", "– b" }, vim.list_slice(page_lines("spread/today"), 2))

    local today_win = page_win("spread/today")
    assert.are.equal(today_win, vim.api.nvim_get_current_win())
    assert.are.same({ 3, 0 }, vim.api.nvim_win_get_cursor(today_win))

    local left = vim.api.nvim_win_get_config(page_win("spread/previous"))
    local right = vim.api.nvim_win_get_config(today_win)
    assert.are.equal(left.row, right.row)
    assert.is_true(right.col > left.col)
  end)

  it("shows the empty state on a blank previous day", function()
    write_file("2026-10-18", "")
    vim.cmd("Bujo spread")
    assert.matches("^2026%-10%-18", page_lines("spread/previous")[1])
    assert.are.equal("no entries", page_lines("spread/previous")[2])
  end)

  it("stacks the pages on narrow editors", function()
    vim.o.columns = 70
    vim.cmd("Bujo spread")
    local top = vim.api.nvim_win_get_config(page_win("spread/previous"))
    local bottom = vim.api.nvim_win_get_config(page_win("spread/today"))
    assert.are.equal(top.col, bottom.col)
    assert.is_true(bottom.row > top.row + top.height)
  end)

  it("re-lays out when the editor is resized", function()
    vim.cmd("Bujo spread")
    vim.o.columns = 70
    vim.api.nvim_exec_autocmds("VimResized", {})
    local top = vim.api.nvim_win_get_config(page_win("spread/previous"))
    local bottom = vim.api.nvim_win_get_config(page_win("spread/today"))
    assert.are.equal(top.col, bottom.col)
  end)

  it("switches pages with <Tab>", function()
    vim.cmd("Bujo spread")
    vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
    assert.are.equal(page_win("spread/previous"), vim.api.nvim_get_current_win())
    vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
    assert.are.equal(page_win("spread/today"), vim.api.nvim_get_current_win())
  end)

  it("changes the previous day's tasks and adds new entries to today", function()
    write_file("2026-10-16", "• friday task\n")
    vim.cmd("Bujo spread")
    vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_feedkeys("x", "x", false)
    assert.are.equal("× friday task", page_lines("spread/previous")[2])

    local real_input = vim.ui.input
    vim.ui.input = function(_, cb)
      cb("from the left page")
    end
    vim.api.nvim_feedkeys("t", "x", false)
    vim.ui.input = real_input
    assert.are.equal("• from the left page", page_lines("spread/today")[2])
    assert.are.equal(1, #store.read_day("2026-10-16"))
  end)

  it("migrates the previous day's task onto today's page", function()
    write_file("2026-10-16", "• friday task\n")
    vim.cmd("Bujo spread")
    vim.api.nvim_set_current_win(page_win("spread/previous"))
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_feedkeys("m", "x", false)
    assert.are.equal("› friday task", page_lines("spread/previous")[2])
    assert.are.equal("• friday task", page_lines("spread/today")[2])
  end)

  it("closes both pages with q and returns to the origin window", function()
    local origin = vim.api.nvim_get_current_win()
    vim.cmd("Bujo spread")
    vim.api.nvim_feedkeys("q", "x", false)
    assert.are.same({}, floats())
    assert.are.equal(origin, vim.api.nvim_get_current_win())
  end)

  it("closes the other page when one is closed with :q", function()
    vim.cmd("Bujo spread")
    vim.cmd("quit")
    vim.wait(100, function()
      return #floats() == 0
    end)
    assert.are.same({}, floats())
  end)

  it("focuses the open spread instead of opening another", function()
    vim.cmd("Bujo spread")
    vim.cmd("wincmd p")
    vim.cmd("Bujo spread")
    assert.are.equal(2, #floats())
    assert.are.equal(page_win("spread/today"), vim.api.nvim_get_current_win())
  end)
end)

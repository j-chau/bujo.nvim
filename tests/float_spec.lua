local config = require("bujo.config")
local date = require("bujo.date")
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

describe("today float", function()
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
    for _, win in ipairs(floats()) do
      vim.api.nvim_win_close(win, true)
    end
    vim.cmd("silent! %bwipeout!")
    vim.fn.delete(dir, "rf")
    config.setup()
  end)

  it("opens today's entries in a centered float with the cursor on the last line", function()
    write_file(TODAY, "• a\n– b\n")
    local origin = vim.api.nvim_get_current_win()
    vim.cmd("Bujo")
    local win = vim.api.nvim_get_current_win()
    assert.are_not.equal(origin, win)
    assert.are.same({ win }, floats())
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({ "• a", "– b" }, vim.list_slice(lines, 2))
    assert.are.equal(config.options.float.width, #lines[1])
    assert.are.same({ 3, 0 }, vim.api.nvim_win_get_cursor(win))
  end)

  it("shows the empty state when today has no file", function()
    vim.cmd("Bujo today")
    assert.are.equal("no entries", vim.api.nvim_buf_get_lines(0, 1, 2, false)[1])
  end)

  it("focuses the existing float instead of opening another", function()
    vim.cmd("Bujo")
    local win = vim.api.nvim_get_current_win()
    vim.cmd("wincmd p")
    vim.cmd("Bujo")
    assert.are.equal(win, vim.api.nvim_get_current_win())
    assert.are.equal(1, #floats())
  end)

  it("fits narrow editors", function()
    config.setup({ data_dir = dir, float = { width = 500 } })
    vim.cmd("Bujo")
    assert.are.equal(vim.o.columns - 4, vim.api.nvim_win_get_width(0))
  end)

  it("adds entries and closes with q, returning to the origin window", function()
    local origin = vim.api.nvim_get_current_win()
    vim.cmd("Bujo")
    local real_input = vim.ui.input
    vim.ui.input = function(_, cb)
      cb("buy milk")
    end
    vim.api.nvim_feedkeys("t", "x", false)
    vim.ui.input = real_input
    assert.are.equal("• buy milk", vim.api.nvim_get_current_line())
    vim.api.nvim_feedkeys("q", "x", false)
    assert.are.same({}, floats())
    assert.are.equal(origin, vim.api.nvim_get_current_win())
    assert.are.equal(1, #store.read_day(TODAY))
  end)

  describe(":Bujo open", function()
    it("edits today's file by default", function()
      vim.cmd("Bujo open")
      assert.are.equal(vim.fs.normalize(store.path_for(TODAY)), vim.fs.normalize(vim.api.nvim_buf_get_name(0)))
    end)

    it("edits the given day's file", function()
      vim.cmd("Bujo open 2026-10-19")
      assert.are.equal(vim.fs.normalize(store.path_for("2026-10-19")), vim.fs.normalize(vim.api.nvim_buf_get_name(0)))
    end)

    it("rejects invalid dates", function()
      local real_notify = vim.notify
      local msg
      vim.notify = function(m, _level, _opts)
        msg = m
      end
      local buf = vim.api.nvim_get_current_buf()
      vim.cmd("Bujo open yesterday")
      vim.notify = real_notify
      assert.matches("invalid date", msg)
      assert.are.equal(buf, vim.api.nvim_get_current_buf())
    end)
  end)

  it("completes subcommands", function()
    assert.are.same({ "open" }, vim.fn.getcompletion("Bujo o", "cmdline"))
  end)
end)

local config = require("bujo.config")
local date = require("bujo.date")
local render = require("bujo.render")
local store = require("bujo.store")
local view = require("bujo.view")

local TODAY = "2026-10-20"

local function read_file(iso)
  local f = io.open(store.path_for(iso), "rb")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

local function write_file(iso, content)
  local path = store.path_for(iso)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local f = assert(io.open(path, "wb"))
  f:write(content)
  f:close()
end

local function today_section()
  return { render.day_section(TODAY, store.read_day(TODAY)) }
end

local function lines(v)
  return vim.api.nvim_buf_get_lines(v.buf, 0, -1, false)
end

-- Shows the view in the current window and renders it.
local function show(v)
  vim.api.nvim_win_set_buf(0, v.buf)
  view.setup_window(0)
  view.render(v)
  return v
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

describe("view", function()
  local dir
  local real_now = date.now
  local real_input = vim.ui.input
  local real_notify = vim.notify
  local n = 0
  local notified

  local function new_view(opts)
    n = n + 1
    return view.create(vim.tbl_extend("force", { name = "bujo://test" .. n, sections = today_section }, opts or {}))
  end

  before_each(function()
    dir = vim.fn.tempname()
    config.setup({ data_dir = dir })
    store.clear_cache()
    date.now = function()
      return os.time({ year = 2026, month = 10, day = 20, hour = 9 })
    end
    notified = {}
    vim.notify = function(msg)
      table.insert(notified, msg)
    end
    write_file(TODAY, "• a\n• b\n– note\n")
  end)

  after_each(function()
    date.now = real_now
    vim.ui.input = real_input
    vim.notify = real_notify
    vim.cmd("silent! only")
    vim.cmd("enew")
    vim.fn.delete(dir, "rf")
    config.setup()
  end)

  it("creates a read-only scratch buffer with window options", function()
    local v = show(new_view())
    assert.are.equal("nofile", vim.bo[v.buf].buftype)
    assert.is_false(vim.bo[v.buf].modifiable)
    assert.are.equal(2, vim.wo.conceallevel)
    assert.are.same({ "• a", "• b", "– note" }, vim.list_slice(lines(v), 2))
  end)

  it("sizes the header to the window's text width", function()
    local v = show(new_view())
    assert.are.equal(vim.api.nvim_win_get_width(0), #lines(v)[1])
  end)

  it("applies actions to the entry under the cursor", function()
    show(new_view())
    cursor_to("• b")
    vim.api.nvim_feedkeys("x", "x", false)
    assert.are.equal("• a\n× b\n– note\n", read_file(TODAY))
    cursor_to("• a")
    vim.api.nvim_feedkeys("c", "x", false)
    assert.are.equal("~• a\n× b\n– note\n", read_file(TODAY))
    vim.api.nvim_feedkeys("r", "x", false)
    assert.are.equal("• a\n× b\n– note\n", read_file(TODAY))
  end)

  it("keeps the cursor on the entry after an action", function()
    show(new_view())
    cursor_to("• b")
    vim.api.nvim_feedkeys("x", "x", false)
    assert.are.equal("× b", vim.api.nvim_get_current_line())
  end)

  it("refuses and refreshes when the file changed underneath", function()
    local v = show(new_view())
    cursor_to("• b")
    write_file(TODAY, "• new\n• a\n• b\n– note\n")
    vim.api.nvim_feedkeys("x", "x", false)
    assert.are.same({ "entry changed on disk; refresh and try again" }, notified)
    assert.are.equal("• new\n• a\n• b\n– note\n", read_file(TODAY))
    assert.are.same({ "• new", "• a", "• b", "– note" }, vim.list_slice(lines(v), 2))
  end)

  it("ignores actions on headers and warns on disallowed ones", function()
    show(new_view())
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_feedkeys("x", "x", false)
    cursor_to("– note")
    vim.api.nvim_feedkeys("x", "x", false)
    assert.are.same({ "can't complete this entry" }, notified)
    assert.are.equal("• a\n• b\n– note\n", read_file(TODAY))
  end)

  it("adds entries to today from a prompt", function()
    local v = show(new_view())
    vim.ui.input = function(opts, cb)
      assert.are.equal("Note: ", opts.prompt)
      cb("hello")
    end
    vim.api.nvim_feedkeys("n", "x", false)
    assert.are.equal("• a\n• b\n– note\n– hello\n", read_file(TODAY))
    assert.are.equal("– hello", lines(v)[#lines(v)])
  end)

  it("ignores a cancelled or empty prompt", function()
    show(new_view())
    vim.ui.input = function(_, cb)
      cb(nil)
    end
    vim.api.nvim_feedkeys("t", "x", false)
    vim.ui.input = function(_, cb)
      cb("   ")
    end
    vim.api.nvim_feedkeys("t", "x", false)
    assert.are.equal("• a\n• b\n– note\n", read_file(TODAY))
  end)

  it("re-renders every open view after a change", function()
    local other = new_view()
    vim.cmd("vsplit")
    show(other)
    vim.cmd("wincmd p")
    show(new_view())
    cursor_to("• a")
    vim.api.nvim_feedkeys("x", "x", false)
    assert.are.equal("× a", lines(other)[2])
  end)

  it("re-renders on resize so the header fits", function()
    vim.cmd("vsplit")
    local v = show(new_view())
    vim.api.nvim_win_set_width(0, 35)
    view.on_resized({ vim.api.nvim_get_current_win() })
    assert.are.equal(35, #lines(v)[1])
  end)

  it("opens the day file in the origin window and closes the view", function()
    local origin = vim.api.nvim_get_current_win()
    vim.cmd("vsplit")
    local v = show(new_view({ origin_win = origin }))
    cursor_to("• b")
    vim.api.nvim_feedkeys("gf", "x", false)
    assert.is_false(vim.api.nvim_buf_is_valid(v.buf))
    assert.are.equal(origin, vim.api.nvim_get_current_win())
    assert.are.equal(vim.fs.normalize(store.path_for(TODAY)), vim.fs.normalize(vim.api.nvim_buf_get_name(0)))
  end)

  it("closes with q and forgets the view", function()
    vim.cmd("vsplit")
    local v = show(new_view())
    vim.api.nvim_feedkeys("q", "x", false)
    assert.is_false(vim.api.nvim_buf_is_valid(v.buf))
    assert.is_nil(view.get(v.buf))
  end)
end)

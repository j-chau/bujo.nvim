-- A view is a read-only buffer rendered from day sections. Changes go
-- through keymaps that look up the entry under the cursor in the line map.
local actions = require("bujo.actions")
local config = require("bujo.config")
local render = require("bujo.render")
local store = require("bujo.store")

local M = {}

---@class bujo.View
---@field buf integer
---@field sections fun(): bujo.Section[]
---@field origin_win? integer window to open raw day files in
---@field persistent? boolean
---@field close fun()
---@field rendered? bujo.Rendered

---@type table<integer, bujo.View>
local views = {}

---@param buf integer
---@return bujo.View?
function M.get(buf)
  return views[buf]
end

---@param view bujo.View
---@return integer?
local function window_of(view)
  local win = vim.fn.win_findbuf(view.buf)[1]
  return win ~= -1 and win or nil
end

---@param win integer
---@return integer
local function text_width(win)
  local info = vim.fn.getwininfo(win)[1]
  return vim.api.nvim_win_get_width(win) - (info and info.textoff or 0)
end

-- Re-renders the view, keeping the cursor on the same entry when it still exists.
---@param view bujo.View
function M.render(view)
  if not vim.api.nvim_buf_is_valid(view.buf) then
    return
  end
  local win = window_of(view)
  local width = win and text_width(win) or 40
  local before = win and view.rendered and view.rendered.linemap[vim.api.nvim_win_get_cursor(win)[1]]
  local row = win and vim.api.nvim_win_get_cursor(win)[1]

  view.rendered = render.build(view.sections(), width)
  render.apply(view.buf, view.rendered)

  if not win then
    return
  end
  if before and before.index then
    for lnum, info in pairs(view.rendered.linemap) do
      if info.day == before.day and info.index == before.index then
        row = lnum
        break
      end
    end
  end
  row = math.max(1, math.min(row, #view.rendered.lines))
  vim.api.nvim_win_set_cursor(win, { row, 0 })
end

function M.refresh_all()
  for _, view in pairs(views) do
    M.render(view)
  end
end

---@param view bujo.View
---@return bujo.LineInfo?
function M.current(view)
  local win = window_of(view)
  if not (win and view.rendered) then
    return nil
  end
  return view.rendered.linemap[vim.api.nvim_win_get_cursor(win)[1]]
end

local function notify(msg)
  vim.notify(msg, vim.log.levels.WARN, { title = "bujo" })
end

---@param view bujo.View
---@param action "complete"|"cancel"|"migrate"|"reopen"
function M.act(view, action)
  local info = M.current(view)
  if not (info and info.entry) then
    return
  end
  local ok, err = actions[action](info.day, info.index, info.entry)
  if not ok then
    notify(err)
  end
  M.refresh_all()
end

local KIND_PROMPTS = { task = "Task: ", note = "Note: ", event = "Event: ", future = "Future event: " }

-- Asks for text and adds an entry of `kind` to today.
---@param kind "task"|"note"|"event"|"future"
function M.add(kind)
  vim.ui.input({ prompt = KIND_PROMPTS[kind] }, function(text)
    if text and vim.trim(text) ~= "" then
      actions.add(kind, text)
      M.refresh_all()
    end
  end)
end

-- Asks for the kind of entry, then its text.
function M.add_any()
  local kinds = { "task", "note", "event", "future" }
  vim.ui.select(kinds, {
    prompt = "Add",
    format_item = function(kind)
      return KIND_PROMPTS[kind]:gsub(": $", "")
    end,
  }, function(kind)
    if kind then
      M.add(kind)
    end
  end)
end

-- Opens the raw file of the day under the cursor in the window the view was
-- opened from, closing the view. Persistent views stay open and use the
-- previous window instead, or a new split if there is none.
---@param view bujo.View
function M.open_file(view)
  local info = M.current(view)
  if not info then
    return
  end
  local path = store.path_for(info.day)
  if view.persistent then
    vim.cmd("wincmd p")
    if vim.api.nvim_get_current_buf() == view.buf then
      vim.cmd("leftabove vsplit")
    end
  else
    local origin = view.origin_win
    view.close()
    if origin and vim.api.nvim_win_is_valid(origin) then
      vim.api.nvim_set_current_win(origin)
    end
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
end

---@param view bujo.View
---@param lhs string|string[]
---@param fn fun()
---@param desc string
function M.map(view, lhs, fn, desc)
  for _, key in ipairs(type(lhs) == "table" and lhs or { lhs }) do
    vim.keymap.set("n", key, fn, { buffer = view.buf, nowait = true, desc = "bujo: " .. desc })
  end
end

---@param view bujo.View
local function set_keymaps(view)
  local keys = config.options.keymaps
  for _, action in ipairs({ "complete", "cancel", "migrate", "reopen" }) do
    M.map(view, keys[action], function()
      M.act(view, action)
    end, action)
  end
  M.map(view, keys.add, M.add_any, "add entry")
  for _, kind in ipairs({ "task", "note", "event", "future" }) do
    M.map(view, keys["add_" .. kind], function()
      M.add(kind)
    end, "add " .. kind)
  end
  M.map(view, keys.open_file, function()
    M.open_file(view)
  end, "open day file")
  M.map(view, keys.close, function()
    view.close()
  end, "close")
end

-- Window options a view needs; call after showing the view's buffer.
---@param win integer
function M.setup_window(win)
  local wo = vim.wo[win]
  wo.conceallevel = 2
  wo.concealcursor = "nvic"
  wo.cursorline = true
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.foldcolumn = "0"
  wo.spell = false
  wo.list = false
  wo.wrap = false
end

---@class bujo.ViewOpts
---@field name string buffer name
---@field sections fun(): bujo.Section[]
---@field origin_win? integer
---@field persistent? boolean keep the view open when opening a day file
---@field close? fun(view: bujo.View) defaults to closing the view's windows

---@param opts bujo.ViewOpts
---@return bujo.View
function M.create(opts)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, opts.name)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "bujo"
  vim.bo[buf].modifiable = false

  ---@type bujo.View
  local view
  view = {
    buf = buf,
    sections = opts.sections,
    origin_win = opts.origin_win,
    persistent = opts.persistent,
    close = function()
      if opts.close then
        return opts.close(view)
      end
      for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        pcall(vim.api.nvim_win_close, win, true)
      end
    end,
  }
  views[buf] = view

  set_keymaps(view)
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      views[buf] = nil
    end,
  })
  return view
end

-- Re-renders views whose windows changed size, so header rules fit.
---@param wins integer[]
function M.on_resized(wins)
  for _, view in pairs(views) do
    for _, win in ipairs(wins) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == view.buf then
        M.render(view)
        break
      end
    end
  end
end

local group = vim.api.nvim_create_augroup("bujo_views", { clear = true })

vim.api.nvim_create_autocmd("WinResized", {
  group = group,
  callback = function()
    M.on_resized(vim.v.event.windows or {})
  end,
})

-- Picks up a new "today" after midnight and edits made outside the plugin.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  group = group,
  callback = function(ev)
    if ev.event == "FocusGained" then
      M.refresh_all()
    elseif views[ev.buf] then
      M.render(views[ev.buf])
    end
  end,
})

return M

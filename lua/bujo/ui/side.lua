local config = require("bujo.config")
local date = require("bujo.date")
local render = require("bujo.render")
local store = require("bujo.store")
local view = require("bujo.view")

local M = {}

---@type bujo.View?
local side_view

-- Open tasks from older days, oldest first, then the last `side_days` days
-- that have a file in full. Today is always one of those days.
---@return bujo.Section[]
function M.sections()
  local today = date.today()
  local lookback = config.options.side_lookback_days
  if type(lookback) ~= "number" or lookback % 1 ~= 0 then
    lookback = 0
  end
  local oldest = date.add_days(today, -lookback)

  local past = vim.tbl_filter(function(day)
    return day < today
  end, store.list_days())
  local split = math.max(0, #past - (config.options.side_days - 1))

  local sections = {}
  for i = 1, lookback > 0 and split or 0 do
    local day = past[i]
    if day >= oldest then
      local items = {}
      for index, e in ipairs(store.read_day(day)) do
        if e.kind == "task" and e.state == "open" then
          table.insert(items, { index = index, entry = e })
        end
      end
      if #items > 0 then
        table.insert(sections, { day = day, items = items })
      end
    end
  end

  for i = split + 1, #past do
    table.insert(sections, render.day_section(past[i], store.read_day(past[i])))
  end
  table.insert(sections, render.day_section(today, store.read_day(today)))
  return sections
end

---@return integer?
local function side_window()
  if side_view and vim.api.nvim_buf_is_valid(side_view.buf) then
    return vim.fn.win_findbuf(side_view.buf)[1]
  end
end

function M.close()
  local win = side_window()
  if win then
    side_view.close()
  end
end

function M.open()
  local existing = side_window()
  if existing then
    vim.api.nvim_set_current_win(existing)
    return
  end

  side_view = view.create({
    name = "bujo://side",
    persistent = true,
    sections = M.sections,
  })
  vim.cmd("botright vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, side_view.buf)
  vim.api.nvim_win_set_width(win, config.options.side_width)
  vim.wo[win].winfixwidth = true
  view.setup_window(win)
  view.render(side_view)
  vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(side_view.buf), 0 })
end

function M.toggle()
  if side_window() then
    M.close()
  else
    M.open()
  end
end

return M

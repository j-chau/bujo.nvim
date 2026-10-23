local config = require("bujo.config")
local date = require("bujo.date")
local render = require("bujo.render")
local store = require("bujo.store")
local view = require("bujo.view")

local M = {}

---@type bujo.View?
local today_view

---@type { previous: bujo.View, today: bujo.View, wins: integer[], augroup: integer }?
local spread

---@return integer
local function float_height()
  return math.max(1, math.floor((vim.o.lines - vim.o.cmdheight) * config.options.float.height))
end

---@param height integer outer height including borders
---@return integer
local function centered_row(height)
  return math.max(0, math.floor((vim.o.lines - vim.o.cmdheight - height) / 2))
end

---@param buf integer
---@param win_config table
---@return integer
local function open_float(buf, win_config)
  local win = vim.api.nvim_open_win(
    buf,
    true,
    vim.tbl_extend("force", {
      relative = "editor",
      style = "minimal",
      border = config.options.float.border,
      title_pos = "center",
    }, win_config)
  )
  view.setup_window(win)
  return win
end

---@param win integer
local function cursor_to_end(win)
  local buf = vim.api.nvim_win_get_buf(win)
  vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
end

---@param v bujo.View?
---@return integer?
local function window_of(v)
  if v and vim.api.nvim_buf_is_valid(v.buf) then
    return vim.fn.win_findbuf(v.buf)[1]
  end
end

function M.open_today()
  local existing = window_of(today_view)
  if existing then
    vim.api.nvim_set_current_win(existing)
    return
  end

  today_view = view.create({
    name = "bujo://today",
    origin_win = vim.api.nvim_get_current_win(),
    sections = function()
      local today = date.today()
      return { render.day_section(today, store.read_day(today)) }
    end,
  })

  local width = math.min(config.options.float.width, vim.o.columns - 4)
  local height = float_height()
  local win = open_float(today_view.buf, {
    width = width,
    height = height,
    row = math.max(0, centered_row(height) - 1),
    col = math.floor((vim.o.columns - width) / 2),
    title = " bujo ",
  })
  view.render(today_view)
  cursor_to_end(win)
end

-- The page left of today: the latest earlier day with a file, or the
-- calendar day before when there is none.
---@return string
function M.previous_day()
  local today = date.today()
  return store.previous_day(today) or date.add_days(today, -1)
end

-- Window configs for the previous and today pages. Side by side when the
-- editor is wide enough, otherwise stacked with the previous page on top.
---@return table previous, table today
function M.spread_layout()
  local opts = config.options.float
  local height = float_height()
  if vim.o.columns >= opts.min_spread_width then
    local width = math.min(opts.width, math.floor((vim.o.columns - 8) / 2))
    local left = math.floor((vim.o.columns - (2 * width + 4)) / 2)
    local row = math.max(0, centered_row(height) - 1)
    return { width = width, height = height, row = row, col = left },
      { width = width, height = height, row = row, col = left + width + 2 }
  end
  local width = math.min(opts.width, vim.o.columns - 4)
  local page_height = math.max(1, math.floor((height - 2) / 2))
  local top = centered_row(2 * page_height + 4)
  local col = math.floor((vim.o.columns - width) / 2)
  return { width = width, height = page_height, row = top, col = col },
    { width = width, height = page_height, row = top + page_height + 2, col = col }
end

local function close_spread()
  if not spread then
    return
  end
  local s = spread
  spread = nil
  pcall(vim.api.nvim_del_augroup_by_id, s.augroup)
  for _, win in ipairs(s.wins) do
    pcall(vim.api.nvim_win_close, win, true)
  end
end

local function relayout_spread()
  if not spread then
    return
  end
  local previous, today = M.spread_layout()
  for i, layout in ipairs({ previous, today }) do
    local win = spread.wins[i]
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_config(win, vim.tbl_extend("force", { relative = "editor" }, layout))
    end
  end
  view.render(spread.previous)
  view.render(spread.today)
end

function M.open_spread()
  local existing = spread and window_of(spread.today)
  if existing then
    vim.api.nvim_set_current_win(existing)
    return
  end

  local origin = vim.api.nvim_get_current_win()
  local previous_view = view.create({
    name = "bujo://spread/previous",
    origin_win = origin,
    close = close_spread,
    sections = function()
      local day = M.previous_day()
      return { render.day_section(day, store.read_day(day)) }
    end,
  })
  local today_page = view.create({
    name = "bujo://spread/today",
    origin_win = origin,
    close = close_spread,
    sections = function()
      local today = date.today()
      return { render.day_section(today, store.read_day(today)) }
    end,
  })

  local previous_layout, today_layout = M.spread_layout()
  local previous_win = open_float(previous_view.buf, vim.tbl_extend("force", previous_layout, { title = " previous " }))
  local today_win = open_float(today_page.buf, vim.tbl_extend("force", today_layout, { title = " today " }))
  view.render(previous_view)
  view.render(today_page)
  cursor_to_end(previous_win)
  cursor_to_end(today_win)

  local augroup = vim.api.nvim_create_augroup("bujo_spread", { clear = true })
  spread = { previous = previous_view, today = today_page, wins = { previous_win, today_win }, augroup = augroup }

  local key = config.options.keymaps.switch_page
  view.map(previous_view, key, function()
    vim.api.nvim_set_current_win(today_win)
  end, "switch page")
  view.map(today_page, key, function()
    vim.api.nvim_set_current_win(previous_win)
  end, "switch page")

  -- Closing either page (e.g. with :q) closes the other.
  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    pattern = { tostring(previous_win), tostring(today_win) },
    callback = function()
      vim.schedule(close_spread)
    end,
  })
  vim.api.nvim_create_autocmd("VimResized", { group = augroup, callback = relayout_spread })
end

return M

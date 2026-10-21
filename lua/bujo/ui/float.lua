local config = require("bujo.config")
local date = require("bujo.date")
local render = require("bujo.render")
local store = require("bujo.store")
local view = require("bujo.view")

local M = {}

---@type bujo.View?
local today_view

---@return integer width, integer height, integer row, integer col
local function centered_size()
  local opts = config.options.float
  local width = math.min(opts.width, vim.o.columns - 4)
  local height = math.max(1, math.floor((vim.o.lines - vim.o.cmdheight) * opts.height))
  local row = math.floor((vim.o.lines - vim.o.cmdheight - height) / 2) - 1
  local col = math.floor((vim.o.columns - width) / 2)
  return width, height, math.max(0, row), col
end

function M.open_today()
  if today_view and vim.api.nvim_buf_is_valid(today_view.buf) then
    local win = vim.fn.win_findbuf(today_view.buf)[1]
    if win then
      vim.api.nvim_set_current_win(win)
      return
    end
  end

  today_view = view.create({
    name = "bujo://today",
    origin_win = vim.api.nvim_get_current_win(),
    sections = function()
      local today = date.today()
      return { render.day_section(today, store.read_day(today)) }
    end,
  })

  local width, height, row, col = centered_size()
  local win = vim.api.nvim_open_win(today_view.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = config.options.float.border,
    title = " bujo ",
    title_pos = "center",
  })
  view.setup_window(win)
  view.render(today_view)
  vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(today_view.buf), 0 })
end

return M

-- Turns day sections into buffer lines, a line -> entry map, and highlights.
-- Lines are the file lines as written, so the glyphs need no overlay.
local date = require("bujo.date")
local entry = require("bujo.entry")
local parser = require("bujo.parser")

local M = {}

M.ns = vim.api.nvim_create_namespace("bujo")

M.EMPTY = "no entries"

---@class bujo.Item
---@field index integer position in the day's entries
---@field entry bujo.Entry

---@class bujo.Section
---@field day string
---@field items bujo.Item[]

---@class bujo.LineInfo
---@field day string
---@field index? integer
---@field entry? bujo.Entry

---@class bujo.Mark
---@field row integer 0-based
---@field col integer
---@field end_col integer
---@field hl? string
---@field conceal? boolean

---@class bujo.Rendered
---@field lines string[]
---@field linemap table<integer, bujo.LineInfo> keyed by 1-based line number
---@field marks bujo.Mark[]

-- A section showing every entry of a day.
---@param day string
---@param entries bujo.Entry[]
---@return bujo.Section
function M.day_section(day, entries)
  local items = {}
  for i, e in ipairs(entries) do
    table.insert(items, { index = i, entry = e })
  end
  return { day = day, items = items }
end

-- Blank days and days with only blank lines get the empty state.
---@param items bujo.Item[]
local function is_empty(items)
  for _, item in ipairs(items) do
    if item.entry.kind ~= "raw" or item.entry.text:match("%S") then
      return false
    end
  end
  return true
end

---@param e bujo.Entry
---@param row integer
---@param len integer
---@return bujo.Mark[]
local function entry_marks(e, row, len)
  if e.kind == "raw" then
    return { { row = row, col = 0, end_col = len, hl = "BujoRaw" } }
  end
  if e.state == "cancelled" then
    local prefix = #entry.CANCEL
    return {
      { row = row, col = 0, end_col = prefix, conceal = true },
      { row = row, col = prefix, end_col = len, hl = "BujoCancelled" },
    }
  end
  if e.state == "done" or e.state == "migrated" then
    return { { row = row, col = 0, end_col = len, hl = "BujoDone" } }
  end
  return { { row = row, col = 0, end_col = #entry.glyph(e), hl = "BujoGlyph" } }
end

---@param sections bujo.Section[]
---@param width integer text width of the window, for the header rule
---@return bujo.Rendered
function M.build(sections, width)
  local lines, linemap, marks = {}, {}, {}

  local function add(line, info, line_marks)
    table.insert(lines, line)
    linemap[#lines] = info
    for _, m in ipairs(line_marks or {}) do
      table.insert(marks, m)
    end
  end

  for s, section in ipairs(sections) do
    if s > 1 then
      add("", { day = section.day })
    end
    local header = date.header(section.day, width)
    local row = #lines
    local rule_start = #section.day + 1
    local rule_end = header:find(" ", rule_start + 1, true) - 1
    add(header, { day = section.day }, {
      { row = row, col = 0, end_col = #header, hl = "BujoHeader" },
      { row = row, col = rule_start, end_col = rule_end, hl = "BujoRule" },
    })

    if is_empty(section.items) then
      add(M.EMPTY, { day = section.day }, { { row = #lines, col = 0, end_col = #M.EMPTY, hl = "BujoEmpty" } })
    else
      for _, item in ipairs(section.items) do
        local line = parser.serialize_line(item.entry)
        local info = { day = section.day, index = item.index, entry = item.entry }
        add(line, info, entry_marks(item.entry, #lines, #line))
      end
    end
  end

  return { lines = lines, linemap = linemap, marks = marks }
end

-- Replaces the buffer's contents with a rendered result.
---@param buf integer
---@param rendered bujo.Rendered
function M.apply(buf, rendered)
  M.setup_highlights()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, rendered.lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  for _, m in ipairs(rendered.marks) do
    local opts = { end_col = m.end_col, hl_group = m.hl }
    if m.conceal then
      opts.conceal = ""
    end
    vim.api.nvim_buf_set_extmark(buf, M.ns, m.row, m.col, opts)
  end
end

local highlights_ready = false

function M.setup_highlights()
  if highlights_ready then
    return
  end
  highlights_ready = true

  local function define()
    local set = vim.api.nvim_set_hl
    set(0, "BujoHeader", { default = true, link = "Title" })
    set(0, "BujoRule", { default = true, link = "NonText" })
    set(0, "BujoGlyph", { default = true, link = "Special" })
    set(0, "BujoDone", { default = true, link = "Comment" })
    set(0, "BujoRaw", { default = true, link = "Comment" })
    set(0, "BujoEmpty", { default = true, link = "Comment" })
    local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
    set(0, "BujoCancelled", { default = true, fg = comment.fg, ctermfg = comment.ctermfg, strikethrough = true })
  end

  define()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("bujo_highlights", { clear = true }),
    callback = define,
  })
end

return M

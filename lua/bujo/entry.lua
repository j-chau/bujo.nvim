-- Entries are the lines of a day file. The glyphs are the on-disk format,
-- so they are constants rather than config.
local M = {}

---@alias bujo.Kind "task"|"note"|"event"|"future"|"raw"
---@alias bujo.State "open"|"done"|"migrated"|"cancelled"
---@alias bujo.Action "complete"|"cancel"|"migrate"|"reopen"

---@class bujo.Entry
---@field kind bujo.Kind
---@field state bujo.State
---@field text string

M.CANCEL = "~"

M.GLYPHS = {
  task = "•",
  done = "×",
  migrated = "›",
  note = "–",
  event = "▽",
  future = "▷",
}

---@param kind bujo.Kind
---@param text string
---@return bujo.Entry
function M.new(kind, text)
  return { kind = kind, state = "open", text = text }
end

-- Cancelled entries keep their open glyph.
---@param e bujo.Entry
---@return string?
function M.glyph(e)
  if e.kind == "task" and (e.state == "done" or e.state == "migrated") then
    return M.GLYPHS[e.state]
  end
  return M.GLYPHS[e.kind]
end

local ALLOWED = {
  complete = { task = true },
  migrate = { task = true },
  cancel = { task = true, event = true, future = true },
}

---@param e bujo.Entry
---@param action bujo.Action
---@return boolean
function M.can(e, action)
  if action == "reopen" then
    return e.kind ~= "raw" and e.state ~= "open"
  end
  return e.state == "open" and ALLOWED[action][e.kind] == true
end

local TARGET = { complete = "done", migrate = "migrated", cancel = "cancelled", reopen = "open" }

-- Returns a new entry with the action applied, or nil if it isn't allowed.
---@param e bujo.Entry
---@param action bujo.Action
---@return bujo.Entry?
function M.apply(e, action)
  if not M.can(e, action) then
    return nil
  end
  return { kind = e.kind, state = TARGET[action], text = e.text }
end

return M

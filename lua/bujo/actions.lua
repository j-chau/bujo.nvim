-- Journal changes. Entries are addressed by day and index; callers pass the
-- entry they expect at that index so a stale view can't change the wrong line
-- after the file was edited elsewhere.
local date = require("bujo.date")
local entry = require("bujo.entry")
local store = require("bujo.store")

local M = {}

local function same(a, b)
  return a.kind == b.kind and a.state == b.state and a.text == b.text
end

---@param iso string
---@param index integer
---@param expected bujo.Entry
---@return bujo.Entry[]?, string?
local function load(iso, index, expected)
  local entries = store.read_day(iso)
  local current = entries[index]
  if not (current and same(current, expected)) then
    return nil, "entry changed on disk; refresh and try again"
  end
  return entries
end

---@param iso string
---@param index integer
---@param expected bujo.Entry
---@param action bujo.Action
---@return boolean, string?
local function change(iso, index, expected, action)
  local entries, err = load(iso, index, expected)
  if not entries then
    return false, err
  end
  local updated = entry.apply(entries[index], action)
  if not updated then
    return false, string.format("can't %s this entry", action)
  end
  entries[index] = updated
  store.write_day(iso, entries)
  return true
end

---@return boolean, string?
function M.complete(iso, index, expected)
  return change(iso, index, expected, "complete")
end

---@return boolean, string?
function M.cancel(iso, index, expected)
  return change(iso, index, expected, "cancel")
end

---@return boolean, string?
function M.reopen(iso, index, expected)
  return change(iso, index, expected, "reopen")
end

-- Marks the task migrated and adds an open copy to the next day it belongs
-- on: tomorrow for today's tasks, today for tasks from earlier days.
---@return boolean, string?
function M.migrate(iso, index, expected)
  local entries, err = load(iso, index, expected)
  if not entries then
    return false, err
  end
  local updated = entry.apply(entries[index], "migrate")
  if not updated then
    return false, "can't migrate this entry"
  end
  local today = date.today()
  if iso > today then
    return false, "can't migrate a task from a future day"
  end
  local target_day = iso == today and date.add_days(today, 1) or today
  local target = store.read_day(target_day)
  table.insert(target, entry.new("task", updated.text))
  store.write_day(target_day, target)
  entries[index] = updated
  store.write_day(iso, entries)
  return true
end

-- Appends a new entry to today. Empty text is ignored.
---@param kind "task"|"note"|"event"|"future"
---@param text string
---@return boolean, string?
function M.add(kind, text)
  text = vim.trim(text or "")
  if text == "" then
    return false, "nothing to add"
  end
  local today = date.today()
  local entries = store.read_day(today)
  table.insert(entries, entry.new(kind, text))
  store.write_day(today, entries)
  return true
end

return M

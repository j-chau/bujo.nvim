-- Dates are ISO "YYYY-MM-DD" strings throughout the plugin, which sort
-- chronologically as plain strings and match the day file names.
local M = {}

local WEEKDAYS = { "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday" }

-- Overridable clock so tests can pin "today".
M.now = os.time

---@param iso string
---@return { year: integer, month: integer, day: integer }?
function M.parse(iso)
  local y, m, d = tostring(iso):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if not y then
    return nil
  end
  local t = { year = tonumber(y), month = tonumber(m), day = tonumber(d) }
  -- Round-trip through os.time to reject dates like 2026-02-30.
  local norm = os.date("*t", os.time({ year = t.year, month = t.month, day = t.day, hour = 12 }))
  if norm.year ~= t.year or norm.month ~= t.month or norm.day ~= t.day then
    return nil
  end
  return t
end

---@param iso string
---@return boolean
function M.is_valid(iso)
  return M.parse(iso) ~= nil
end

-- Noon avoids DST transitions shifting the result onto a neighbouring day.
---@param iso string
---@return integer
local function to_time(iso)
  local t = assert(M.parse(iso), "invalid date: " .. tostring(iso))
  return os.time({ year = t.year, month = t.month, day = t.day, hour = 12 })
end

---@return string
function M.today()
  return os.date("%Y-%m-%d", M.now()) --[[@as string]]
end

---@param iso string
---@param n integer
---@return string
function M.add_days(iso, n)
  local t = assert(M.parse(iso), "invalid date: " .. tostring(iso))
  return os.date("%Y-%m-%d", os.time({ year = t.year, month = t.month, day = t.day + n, hour = 12 })) --[[@as string]]
end

---@param a string
---@param b string
---@return integer
function M.diff_days(a, b)
  return math.floor(os.difftime(to_time(b), to_time(a)) / 86400 + 0.5)
end

-- Header format: 
-- YYYY-MM-DD ---------------- dddd
---@param iso string
---@param width integer
---@return string
function M.header(iso, width)
  local day = WEEKDAYS[os.date("*t", to_time(iso)).wday]
  local dashes = math.max(3, width - #iso - #day - 2)
  return string.format("%s %s %s", iso, string.rep("-", dashes), day)
end

return M

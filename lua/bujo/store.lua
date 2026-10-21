-- One file per day at <data_dir>/YYYY/YYYY-MM-DD.md.
local config = require("bujo.config")
local parser = require("bujo.parser")

local uv = vim.uv
local M = {}

-- path -> { mtime_sec, mtime_nsec, size, entries }
local cache = {}

---@param iso string
---@return string
function M.path_for(iso)
  return string.format("%s/%s/%s.md", config.options.data_dir, iso:sub(1, 4), iso)
end

local function same_stat(cached, stat)
  return cached.mtime_sec == stat.mtime.sec
    and cached.mtime_nsec == stat.mtime.nsec
    and cached.size == stat.size
end

local function remember(path, stat, entries)
  cache[path] = {
    mtime_sec = stat.mtime.sec,
    mtime_nsec = stat.mtime.nsec,
    size = stat.size,
    entries = entries,
  }
end

-- Missing days read as empty. Returns a copy, so callers may modify it.
---@param iso string
---@return bujo.Entry[]
function M.read_day(iso)
  local path = M.path_for(iso)
  local stat = uv.fs_stat(path)
  if not stat then
    cache[path] = nil
    return {}
  end
  local cached = cache[path]
  if not (cached and same_stat(cached, stat)) then
    local fd = assert(uv.fs_open(path, "r", 438))
    local content = assert(uv.fs_read(fd, stat.size, 0))
    uv.fs_close(fd)
    remember(path, stat, parser.parse(content))
    cached = cache[path]
  end
  return vim.deepcopy(cached.entries)
end

-- Writes to a temp file and renames it over the day file, so a crash or a
-- sync client never sees a half-written day. An empty day removes the file.
---@param iso string
---@param entries bujo.Entry[]
function M.write_day(iso, entries)
  local path = M.path_for(iso)
  local content = parser.serialize(entries)
  if content == "" then
    os.remove(path)
    cache[path] = nil
    return
  end
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local tmp = path .. ".tmp"
  local fd = assert(uv.fs_open(tmp, "w", 420))
  assert(uv.fs_write(fd, content, 0))
  uv.fs_close(fd)
  assert(uv.fs_rename(tmp, path))
  remember(path, assert(uv.fs_stat(path)), vim.deepcopy(entries))
end

-- All days that have a file, oldest first.
---@return string[]
function M.list_days()
  local days = {}
  local root = config.options.data_dir
  if not uv.fs_stat(root) then
    return days
  end
  for name, kind in vim.fs.dir(root, { depth = 2 }) do
    local iso = name:match("^%d%d%d%d/(%d%d%d%d%-%d%d%-%d%d)%.md$")
    if kind == "file" and iso then
      table.insert(days, iso)
    end
  end
  table.sort(days)
  return days
end

-- The most recent day before `iso` that has a file.
---@param iso string
---@return string?
function M.previous_day(iso)
  local days = M.list_days()
  for i = #days, 1, -1 do
    if days[i] < iso then
      return days[i]
    end
  end
  return nil
end

function M.clear_cache()
  cache = {}
end

return M

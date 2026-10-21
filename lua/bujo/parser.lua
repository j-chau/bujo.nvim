local entry = require("bujo.entry")

local M = {}

-- glyph -> { kind, state }
local BY_GLYPH = {
  [entry.GLYPHS.task] = { "task", "open" },
  [entry.GLYPHS.done] = { "task", "done" },
  [entry.GLYPHS.migrated] = { "task", "migrated" },
  [entry.GLYPHS.note] = { "note", "open" },
  [entry.GLYPHS.event] = { "event", "open" },
  [entry.GLYPHS.future] = { "future", "open" },
}

local function raw(line)
  return { kind = "raw", state = "open", text = line }
end

-- Lines that don't look like "<glyph> text" are kept verbatim as raw entries.
-- A leading "*" is read as a task and the space after the glyph is optional,
-- so hand-typed "*buy milk" or "•buy milk" are written back as "• buy milk".
---@param line string
---@return bujo.Entry
function M.parse_line(line)
  local cancelled = vim.startswith(line, entry.CANCEL)
  local rest = cancelled and line:sub(#entry.CANCEL + 1) or line
  if rest:match("^%*") and not rest:match("^%*%*") then
    rest = entry.GLYPHS.task .. rest:sub(2)
  end
  for glyph, ks in pairs(BY_GLYPH) do
    if vim.startswith(rest, glyph) then
      local kind, state = ks[1], ks[2]
      if cancelled then
        -- Only the open glyph of a cancellable kind can carry the prefix.
        if state ~= "open" or kind == "note" then
          return raw(line)
        end
        state = "cancelled"
      end
      local text = rest:sub(#glyph + 1)
      return { kind = kind, state = state, text = text:gsub("^ ", "", 1) }
    end
  end
  return raw(line)
end

---@param e bujo.Entry
---@return string
function M.serialize_line(e)
  if e.kind == "raw" then
    return e.text
  end
  local prefix = e.state == "cancelled" and entry.CANCEL or ""
  return prefix .. entry.glyph(e) .. " " .. e.text
end

---@param content string
---@return bujo.Entry[]
function M.parse(content)
  local entries = {}
  if content == "" then
    return entries
  end
  local lines = vim.split(content:gsub("\r\n", "\n"), "\n", { plain = true })
  if lines[#lines] == "" then
    table.remove(lines)
  end
  for _, line in ipairs(lines) do
    local e = M.parse_line(line)
    -- Empty entries are dropped, so they disappear the next time the day is saved.
    if e.kind == "raw" or not e.text:match("^%s*$") then
      table.insert(entries, e)
    end
  end
  return entries
end

---@param entries bujo.Entry[]
---@return string
function M.serialize(entries)
  if #entries == 0 then
    return ""
  end
  return table.concat(vim.tbl_map(M.serialize_line, entries), "\n") .. "\n"
end

return M

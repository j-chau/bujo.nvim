local M = {}

---@param opts? table
function M.setup(opts)
  require("bujo.config").setup(opts)
end

function M.today()
  require("bujo.ui.float").open_today()
end

-- Opens a day's raw file for editing.
---@param iso? string defaults to today
function M.open(iso)
  local date = require("bujo.date")
  iso = iso or date.today()
  if not date.is_valid(iso) then
    vim.notify("bujo: invalid date " .. iso .. " (expected YYYY-MM-DD)", vim.log.levels.ERROR)
    return
  end
  vim.cmd.edit(vim.fn.fnameescape(require("bujo.store").path_for(iso)))
end

return M

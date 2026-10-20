local M = {}

---@param opts? table
function M.setup(opts)
  require("bujo.config").setup(opts)
end

return M

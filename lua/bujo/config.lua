local M = {}

---@class bujo.Config
M.defaults = {
  -- Day files are stored at <data_dir>/YYYY/YYYY-MM-DD.md
  data_dir = vim.fn.stdpath("data") .. "/bujo",
  side_days = 7,
  side_lookback_days = 30,
  side_width = 50,
  float = {
    width = 60,
    height = 0.7,
    border = "rounded",
    -- Below this many columns the spread stacks yesterday above today.
    min_spread_width = 80,
  },
  keymaps = {
    complete = "x",
    cancel = "c",
    migrate = "m",
    reopen = "r",
    add = "a",
    add_task = "t",
    add_note = "n",
    add_event = "e",
    add_future = "E",
    open_file = "gf",
    switch_page = "<Tab>",
    close = { "q", "<Esc>" },
  },
}

---@type bujo.Config
M.options = vim.deepcopy(M.defaults)

---@param opts? table
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M

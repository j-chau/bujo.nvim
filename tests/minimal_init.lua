local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

-- Prefer an existing plenary checkout, otherwise clone one into .tests/.
local function find_plenary()
  local candidates = {
    vim.env.PLENARY_DIR,
    root .. "/.tests/plenary.nvim",
    vim.fn.stdpath("data") .. "/lazy/plenary.nvim",
  }
  for _, dir in ipairs(candidates) do
    if dir and vim.uv.fs_stat(dir) then
      return dir
    end
  end
  local dir = root .. "/.tests/plenary.nvim"
  vim.fn.system({ "git", "clone", "--depth", "1", "https://github.com/nvim-lua/plenary.nvim", dir })
  return dir
end

vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(find_plenary())
vim.opt.swapfile = false
vim.cmd("runtime plugin/plenary.vim")
vim.cmd("runtime plugin/bujo.lua")

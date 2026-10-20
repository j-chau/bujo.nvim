if vim.g.loaded_bujo then
  return
end
vim.g.loaded_bujo = true

if vim.fn.has("nvim-0.11") == 0 then
  vim.notify("bujo.nvim requires Neovim 0.11+", vim.log.levels.ERROR)
  return
end

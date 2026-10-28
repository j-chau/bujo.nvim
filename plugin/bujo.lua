if vim.g.loaded_bujo then
  return
end
vim.g.loaded_bujo = true

if vim.fn.has("nvim-0.11") == 0 then
  vim.notify("bujo.nvim requires Neovim 0.11+", vim.log.levels.ERROR)
  return
end

local subcommands = {
  today = function()
    require("bujo").today()
  end,
  spread = function()
    require("bujo").spread()
  end,
  side = function()
    require("bujo").side()
  end,
  open = function(args)
    require("bujo").open(args[1])
  end,
}

vim.api.nvim_create_user_command("Bujo", function(cmd)
  local name = cmd.fargs[1] or "today"
  local sub = subcommands[name]
  if not sub then
    vim.notify("bujo: unknown subcommand " .. name, vim.log.levels.ERROR)
    return
  end
  sub(vim.list_slice(cmd.fargs, 2))
end, {
  nargs = "*",
  desc = "Bullet journal",
  complete = function(arg_lead, line)
    if #vim.split(line, "%s+", { trimempty = true }) > (arg_lead == "" and 1 or 2) then
      return {}
    end
    return vim.tbl_filter(function(name)
      return vim.startswith(name, arg_lead)
    end, vim.tbl_keys(subcommands))
  end,
})

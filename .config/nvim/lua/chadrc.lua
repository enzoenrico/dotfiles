---@type ChadrcConfig
local M = {}

local function current_theme()
  if vim.fn.has "macunix" ~= 1 then
    return "vesper"
  end

  local style = vim.trim(vim.fn.system { "defaults", "read", "-g", "AppleInterfaceStyle" })

  if vim.v.shell_error == 0 and style == "Dark" then
    return "vesper"
  end

  return "ayu_light"
end

M.base46 = {
  theme = current_theme(),
  theme_toggle = { "vesper", "ayu_light" },
}

return M

---@type ChadrcConfig
local M = {}

M.themes = {
  dark = "catppuccin",
  light = "catppuccin-latte",
}

function M.detect_system_theme()
  if vim.fn.has "macunix" ~= 1 then
    return M.themes.dark, "dark"
  end

  local style = vim.trim(vim.fn.system { "defaults", "read", "-g", "AppleInterfaceStyle" })

  if vim.v.shell_error == 0 and style == "Dark" then
    return M.themes.dark, "dark"
  end

  return M.themes.light, "light"
end

local theme = select(1, M.detect_system_theme())

M.base46 = {
  theme = theme,
  theme_toggle = { M.themes.dark, M.themes.light },
}

M.ui = {
  tabufline = {
    lazyload = false,
  },
}

return M

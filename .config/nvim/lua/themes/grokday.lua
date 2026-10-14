-- GrokDay for NvChad base46.
-- Palette from xai-org/grok-build grokday.rs (Grok Build light theme).

local M = {}

M.base_30 = {
  white = "#262626",
  darker_black = "#eaeaea",
  black = "#f5f5f5",
  black2 = "#eeeeee",
  one_bg = "#dedede",
  one_bg2 = "#d0d0d0",
  one_bg3 = "#c6c6c6",
  grey = "#b2b2b2",
  grey_fg = "#a5a5a5",
  grey_fg2 = "#8e8e8e",
  light_grey = "#767676",
  red = "#CD3048",
  baby_pink = "#CD3048",
  pink = "#7D4BC6",
  line = "#dedede",
  green = "#378E23",
  vibrant_green = "#0C947C",
  nord_blue = "#2F64D2",
  blue = "#2F64D2",
  yellow = "#A27612",
  sun = "#A8780A",
  purple = "#7D4BC6",
  dark_purple = "#6C3EB2",
  teal = "#0A8E70",
  orange = "#C3691E",
  cyan = "#0082AA",
  statusline_bg = "#eaeaea",
  lightbg = "#e4e4e4",
  pmenu_bg = "#7D4BC6",
  folder_bg = "#2F64D2",
  lavender = "#444444",
}

M.base_16 = {
  base00 = "#f5f5f5",
  base01 = "#eeeeee",
  base02 = "#dedede",
  base03 = "#767676",
  base04 = "#626262",
  base05 = "#262626",
  base06 = "#444444",
  base07 = "#262626",
  base08 = "#CD3048",
  base09 = "#C3691E",
  base0A = "#A27612",
  base0B = "#378E23",
  base0C = "#0082AA",
  base0D = "#2F64D2",
  base0E = "#7D4BC6",
  base0F = "#AF2323",
}

M.polish_hl = {
  treesitter = {
    ["@property"] = { fg = M.base_30.teal },
    ["@variable.builtin"] = { fg = M.base_30.red },
  },
}

M.type = "light"

M = require("base46").override_theme(M, "grokday")

return M

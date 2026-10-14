-- GrokNight for NvChad base46.
-- Palette from xai-org/grok-build groknight.rs (Grok Build dark theme).

local M = {}

M.base_30 = {
  white = "#e1e1e1",
  darker_black = "#0a0a0a",
  black = "#141414",
  black2 = "#1c1c1c",
  one_bg = "#242424",
  one_bg2 = "#2c2c2c",
  one_bg3 = "#363636",
  grey = "#414141",
  grey_fg = "#585858",
  grey_fg2 = "#5a5a5a",
  light_grey = "#6c6c6c",
  red = "#f7768e",
  baby_pink = "#f7768e",
  pink = "#bb9af7",
  line = "#242424",
  green = "#9ece6a",
  vibrant_green = "#73daca",
  nord_blue = "#7aa2f7",
  blue = "#7aa2f7",
  yellow = "#e0af68",
  sun = "#FFDB8D",
  purple = "#bb9af7",
  dark_purple = "#9d7cd8",
  teal = "#1abc9c",
  orange = "#ff9e64",
  cyan = "#7dcfff",
  statusline_bg = "#0c0c0c",
  lightbg = "#1c1c1c",
  pmenu_bg = "#bb9af7",
  folder_bg = "#7aa2f7",
  lavender = "#c8c8c8",
}

M.base_16 = {
  base00 = "#141414",
  base01 = "#1c1c1c",
  base02 = "#242424",
  base03 = "#6c6c6c",
  base04 = "#787878",
  base05 = "#e1e1e1",
  base06 = "#c8c8c8",
  base07 = "#e1e1e1",
  base08 = "#f7768e",
  base09 = "#ff9e64",
  base0A = "#e0af68",
  base0B = "#9ece6a",
  base0C = "#7dcfff",
  base0D = "#7aa2f7",
  base0E = "#bb9af7",
  base0F = "#db4b4b",
}

M.polish_hl = {
  treesitter = {
    ["@variable"] = { fg = M.base_30.lavender },
    ["@property"] = { fg = M.base_30.teal },
    ["@variable.builtin"] = { fg = M.base_30.red },
  },
}

M.type = "dark"

M = require("base46").override_theme(M, "groknight")

return M

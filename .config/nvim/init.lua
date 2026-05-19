vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

local function detect_system_theme()
  if vim.fn.has "macunix" ~= 1 then
    return "vesper", "dark"
  end

  local style = vim.trim(vim.fn.system { "defaults", "read", "-g", "AppleInterfaceStyle" })

  if vim.v.shell_error == 0 and style == "Dark" then
    return "vesper", "dark"
  end

  return "ayu_light", "light"
end

local function sync_system_theme(force)
  local theme, preview_theme = detect_system_theme()
  local nvconfig = require "nvconfig"

  if not force and nvconfig.base46.theme == theme then
    return
  end

  nvconfig.base46.theme = theme
  require("chadrc").base46.theme = theme
  vim.g.mkdp_theme = preview_theme

  local preview_options = vim.deepcopy(vim.g.mkdp_preview_options or {})
  preview_options.maid = vim.tbl_deep_extend("force", preview_options.maid or {}, {
    theme = preview_theme,
  })
  vim.g.mkdp_preview_options = preview_options

  require("base46").load_all_highlights()
end

if vim.g.vscode then
  vim.schedule(function()
    require "mappings"
  end)
  return
end

sync_system_theme(true)

dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "nvchad.autocmds"

vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
  group = vim.api.nvim_create_augroup("system-theme-sync", { clear = true }),
  callback = function()
    sync_system_theme(false)
  end,
})

vim.schedule(function()
  require "mappings"
end)

--- Xcodebuild.nvim + nvim-dap-ui: app logs in a bottom console panel only (no DAP sidebars).
local M = {}

--- Set by build_and_debug before launch; cleared after auto-focusing console.
local awaiting_debug_console = false

local function ensure_dap_ui()
  require("dapui").open()
end

local function focus_console()
  local dapui = require("dapui")
  local console = dapui.elements.console
  if not console or not console.buffer then
    return
  end

  local buf = console.buffer()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local wins = vim.fn.win_findbuf(buf)
  if not wins[1] then
    ensure_dap_ui()
    wins = vim.fn.win_findbuf(buf)
  end

  if wins[1] then
    vim.api.nvim_set_current_win(wins[1])
    vim.cmd("normal! G")
    return
  end

  dapui.float_element("console", {
    enter = true,
    height = 24,
    width = math.min(120, vim.o.columns - 4),
  })
end

function M.setup_dap_ui()
  local dap = require("dap")

  require("dapui").setup({
    controls = { enabled = false },
    layouts = {
      {
        elements = { "console" },
        size = 0.28,
        position = "bottom",
      },
    },
  })

  dap.listeners.before.attach.xcodebuild_dapui = ensure_dap_ui
  dap.listeners.before.launch.xcodebuild_dapui = ensure_dap_ui
end

M.focus_console = focus_console

function M.build_and_debug()
  awaiting_debug_console = true
  require("xcodebuild.integrations.dap").build_and_debug()
end

function M.close_debug_ui()
  local ok, dap_int = pcall(require, "xcodebuild.integrations.dap")
  if ok and dap_int.terminate_session then
    dap_int.terminate_session()
    return
  end

  pcall(function()
    local dap = require("dap")
    if dap.session() then
      dap.terminate()
    end
    require("dapui").close()
  end)
end

function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("XcodebuildLiveLogs", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "XcodebuildApplicationLaunched",
    callback = function()
      if not awaiting_debug_console then
        return
      end
      awaiting_debug_console = false
      vim.schedule(focus_console)
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "XcodebuildBuildFinished",
    callback = function(ev)
      local data = ev.data or {}
      if not data.success or data.cancelled then
        awaiting_debug_console = false
      end
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "XcodebuildActionCancelled",
    callback = function()
      awaiting_debug_console = false
    end,
  })
end

function M.setup_xcodebuild()
  require("xcodebuild").setup({
    logs = {
      auto_close_on_app_launch = true,
    },
  })
  require("xcodebuild.integrations.dap").setup()
end

return M

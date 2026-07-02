local M = {}

--- Terminal #1: primary float (leader tt). Toggle hides the window; the shell keeps running.
M.float_id = 1
M.opencode_id = 4
M.agent_id = 5

M.opts = {
  size = function(term)
    if term.direction == "horizontal" then
      return math.max(12, math.floor(vim.o.lines * 0.3))
    elseif term.direction == "vertical" then
      return math.floor(vim.o.columns * 0.4)
    elseif term.direction == "float" then
      return math.floor(vim.o.lines * 0.45)
    end
    return 20
  end,
  direction = "float",
  persist_mode = true,
  persist_size = true,
  close_on_exit = false,
  start_in_insert = true,
  insert_mappings = true,
  terminal_mappings = true,
  shade_terminals = false,
  float_opts = {
    border = "rounded",
  },
}

function M.setup()
  if not vim.o.hidden then
    vim.o.hidden = true
  end
  require("toggleterm").setup(M.opts)
end

---@param direction "horizontal"|"vertical"|"float"
---@param id? integer
function M.toggle(direction, id)
  direction = direction or "float"
  id = id
    or (direction == "float" and M.float_id or direction == "vertical" and 2 or 3)
  require("toggleterm").toggle(id, nil, nil, direction)
end

function M.toggle_float()
  M.toggle("float", M.float_id)
end

local function shellescape(value)
  return vim.fn.shellescape(value)
end

local function current_buffer_file()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    return nil, "Current buffer has no file path"
  end

  path = vim.fn.fnamemodify(path, ":p")
  if vim.fn.filereadable(path) == 0 then
    return nil, ("Current buffer is not a readable file: %s"):format(path)
  end

  return path
end

local function workspace_relative_path(path)
  local relative = vim.fn.fnamemodify(path, ":.")

  if relative == path or relative:match("^%.%./") then
    return nil, ("Focused file is outside the current workspace: %s"):format(path)
  end

  return relative
end

local function kill_job(term)
  local job_id = term and term.job_id
  if not job_id or job_id <= 0 then
    return
  end

  pcall(vim.fn.jobstop, job_id)
  term.job_id = nil
end

local function restart_float(id, display_name, cmd, dir)
  local terms = require "toggleterm.terminal"
  local term = terms.get(id, true)

  if term then
    kill_job(term)
    term:shutdown()
  end

  terms.Terminal:new {
    id = id,
    direction = "float",
    dir = dir,
    cmd = cmd,
    display_name = display_name,
    close_on_exit = false,
    hidden = true,
  }:open(nil, "float")
end

local function launch_ai_float(id, display_name, command_builder)
  local path, path_err = current_buffer_file()
  if not path then
    vim.notify(path_err, vim.log.levels.WARN)
    return
  end

  local relative, relative_err = workspace_relative_path(path)
  if not relative then
    vim.notify(relative_err, vim.log.levels.WARN)
    return
  end

  local cwd = vim.fn.getcwd()
  local cmd = command_builder(relative)
  restart_float(id, display_name, cmd, cwd)
end

local function toggle_or_launch(id, display_name, command_builder)
  local terms = require "toggleterm.terminal"
  local term = terms.get(id, true)

  if term and term.job_id and term.job_id > 0 then
    require("toggleterm").toggle(id, nil, nil, "float")
    return
  end

  launch_ai_float(id, display_name, command_builder)
end

function M.open_opencode_with_current_file()
  toggle_or_launch(M.opencode_id, "opencode", function(relative)
    return table.concat({ "opencode", "--prompt", shellescape("@" .. relative) }, " ")
  end)
end

function M.open_agent_with_current_file()
  toggle_or_launch(M.agent_id, "agent", function(relative)
    return table.concat({ "agent", shellescape("@" .. relative) }, " ")
  end)
end

return M

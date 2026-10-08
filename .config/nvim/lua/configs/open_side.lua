--- Open a file in a vertical split to the right of an existing editor window.
--- The window that already shows a file keeps that file.
local M = {}

--- A normal file window: not a float, not the Snacks sidebar.
function M.editor_win()
  local fallback
  local current = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local cfg = vim.api.nvim_win_get_config(win)
    local buf = vim.api.nvim_win_get_buf(win)
    local is_editor = cfg.relative == "" and vim.bo[buf].buftype == "" and not vim.w[win].snacks_layout
    if is_editor then
      if win == current then
        return win
      end
      fallback = fallback or win
    end
  end
  return fallback
end

--- @param path string
--- @param win? integer window that should stay on the original file
--- @return boolean
function M.open(path, win)
  if type(path) ~= "string" or path == "" or vim.fn.isdirectory(path) == 1 then
    return false
  end
  if win and vim.api.nvim_win_is_valid(win) then
    local buf = vim.api.nvim_win_get_buf(win)
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= "" or vim.bo[buf].buftype ~= "" or vim.w[win].snacks_layout then
      win = nil
    end
  else
    win = nil
  end
  win = win or M.editor_win()
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return false
  end
  vim.api.nvim_set_current_win(win)
  vim.cmd("rightbelow vertical split " .. vim.fn.fnameescape(path))
  return true
end

return M

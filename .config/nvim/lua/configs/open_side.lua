--- Open a file in a new vertical split in the editor.
--- Existing panes keep their files. Ctrl+Enter always adds a pane.
local M = {}

--- A normal file window: not a float, not the Snacks sidebar.
--- @param win integer
--- @return boolean
local function is_editor(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return false
  end
  if vim.api.nvim_win_get_config(win).relative ~= "" or vim.w[win].snacks_layout then
    return false
  end
  return vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ""
end

--- Any split we can attach a new pane to, including the home screen.
--- @param win integer
--- @return boolean
local function is_split_target(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return false
  end
  return vim.api.nvim_win_get_config(win).relative == "" and not vim.w[win].snacks_layout
end

--- @param prefer? integer window that should stay on its current file
--- @return integer?
function M.anchor(prefer)
  if is_editor(prefer) then
    return prefer
  end
  local current = vim.api.nvim_get_current_win()
  if is_editor(current) then
    return current
  end

  local editor, other
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor(win) then
      editor = editor or win
    elseif not other and is_split_target(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype ~= "terminal" then
        other = win
      end
    end
  end
  if editor or other then
    return editor or other
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_split_target(win) then
      return win
    end
  end
end

--- Same as <C-w>v on an editor window, then show `buf` in the new pane.
--- Splitting with no filename ignores 'switchbuf' (default "uselast"), which
--- would otherwise reuse the current window.
--- @param buf integer
--- @param win? integer
--- @return boolean
local function open_buf(buf, win)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return false
  end
  local anchor = M.anchor(win)
  if not (anchor and vim.api.nvim_win_is_valid(anchor)) then
    return false
  end
  local kept = vim.api.nvim_win_get_buf(anchor)
  local seen = {}
  for _, existing in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    seen[existing] = true
  end

  vim.api.nvim_set_current_win(anchor)
  vim.cmd("vertical split")
  local new_win = vim.api.nvim_get_current_win()
  if seen[new_win] or new_win == anchor then
    return false
  end
  if vim.bo[buf].buftype == "" then
    vim.bo[buf].buflisted = true
  end
  vim.api.nvim_win_set_buf(new_win, buf)
  if vim.api.nvim_win_is_valid(anchor) and vim.api.nvim_win_get_buf(anchor) ~= kept then
    vim.api.nvim_win_set_buf(anchor, kept)
  end
  vim.api.nvim_set_current_win(new_win)
  return true
end

--- @param path string
--- @param win? integer window that should stay on the original file
--- @return boolean
function M.open(path, win)
  if type(path) ~= "string" or path == "" then
    return false
  end
  path = vim.fn.fnamemodify(path, ":p")
  if vim.fn.isdirectory(path) == 1 then
    return false
  end
  local buf = vim.fn.bufadd(path)
  if not buf or buf == 0 then
    return false
  end
  if vim.bo[buf].buftype == "" then
    vim.bo[buf].buflisted = true
  end
  return open_buf(buf, win)
end

--- @param item table
--- @return integer?
local function buf_from_item(item)
  if item.buf and vim.api.nvim_buf_is_valid(item.buf) then
    local name = vim.api.nvim_buf_get_name(item.buf)
    if name == "" or vim.fn.isdirectory(name) == 0 then
      return item.buf
    end
  end
  if type(item.file) ~= "string" or item.file == "" or vim.fn.isdirectory(item.file) == 1 then
    return nil
  end
  local buf = vim.fn.bufadd(vim.fn.fnamemodify(item.file, ":p"))
  if not buf or buf == 0 then
    return nil
  end
  if vim.bo[buf].buftype == "" then
    vim.bo[buf].buflisted = true
  end
  return buf
end

--- Snacks picker / explorer: Ctrl+Enter opens the file in a new editor split.
--- Directories still expand in the sidebar. A floating picker closes first.
--- @param picker table
--- @param item? table
function M.from_picker(picker, item)
  if not item then
    return
  end
  if item.dir then
    local ok, actions = pcall(require, "snacks.explorer.actions")
    if ok then
      actions.actions.confirm(picker, item, {})
    end
    return
  end

  local buf = buf_from_item(item)
  if not buf then
    return
  end
  local anchor = picker.main
  local pos = item.pos

  local function show()
    if not open_buf(buf, anchor) then
      return
    end
    if type(pos) == "table" and type(pos[1]) == "number" and pos[1] > 0 then
      pcall(vim.api.nvim_win_set_cursor, vim.api.nvim_get_current_win(), { pos[1], pos[2] or 0 })
    end
  end

  local keep = picker.layout and picker.layout.split
  if keep or type(picker.close) ~= "function" then
    show()
    return
  end
  picker:close()
  vim.schedule(show)
end

return M

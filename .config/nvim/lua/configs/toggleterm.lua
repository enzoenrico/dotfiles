local M = {}

--- Terminal #1: primary float (leader tt). Toggle hides the window; the shell keeps running.
M.float_id = 1

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

return M

--- Insert-mode `////` snippet: language-aware commented header block.

local M = {}

local WIDTH = 79

---@return string, string
local function comment_parts()
  local cs = vim.bo.commentstring
  if not cs or cs == "" then
    cs = "// %s"
  end

  local left, right = cs:match "^(.*)%%s(.*)$"
  return vim.trim(left or "//"), vim.trim(right or "")
end

---@param left string
---@return string
local function fill_char(left)
  if left:find "^%-" or left:find '^"' then
    return "-"
  end
  if left:find "^#" then
    return "#"
  end
  return "="
end

---@return string
local function banner()
  local left, right = comment_parts()
  local suffix = right ~= "" and (" " .. right) or ""
  local inner = math.max(8, WIDTH - #left - 1 - #suffix)
  return left .. " " .. string.rep(fill_char(left), inner) .. suffix
end

---@return string
local function title_prefix()
  local left = comment_parts()
  return left .. " "
end

---@return string
local function title_suffix()
  local _, right = comment_parts()
  return right ~= "" and (" " .. right) or ""
end

---@return table
function M.snippet()
  local ls = require "luasnip"
  local f = ls.function_node
  local i = ls.insert_node
  local t = ls.text_node

  return ls.snippet({
    trig = "////",
    name = "Comment header",
    dscr = "Commented header block",
    wordTrig = false,
  }, {
    f(banner),
    t { "", "" },
    f(title_prefix),
    i(1, "Title"),
    f(title_suffix),
    t { "", "" },
    f(banner),
    t { "", "" },
    i(0),
  })
end

function M.setup()
  if M._setup then
    return
  end

  local ok, ls = pcall(require, "luasnip")
  if not ok then
    return
  end

  M._setup = true
  ls.add_snippets("all", { M.snippet() }, { key = "comment_header" })
end

function M.expand()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  if line:sub(1, col):find "%S" then
    vim.api.nvim_feedkeys("////", "n", false)
    return
  end

  local ok, ls = pcall(require, "luasnip")
  if not ok then
    local indent = line:match "^%s*" or ""
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local prefix = title_prefix()
    local suffix = title_suffix()
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, {
      indent .. banner(),
      indent .. prefix .. "Title" .. suffix,
      indent .. banner(),
      indent,
    })
    vim.api.nvim_win_set_cursor(0, { row + 1, #indent + #prefix })
    return
  end

  M.setup()
  ls.snip_expand(M.snippet())
end

return M

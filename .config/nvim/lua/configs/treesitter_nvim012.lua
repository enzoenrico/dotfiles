--- Neovim 0.12 passes capture lists in query match tables; nvim-treesitter
--- query_predicates still expect a single TSNode. Re-register affected handlers.
--- See: https://github.com/nvim-treesitter/nvim-treesitter/issues/8636
local M = {}

local patched = false

local html_script_type_languages = {
  ["importmap"] = "json",
  ["module"] = "javascript",
  ["application/ecmascript"] = "javascript",
  ["text/ecmascript"] = "javascript",
}

local non_filetype_match_injection_language_aliases = {
  ex = "elixir",
  pl = "perl",
  sh = "bash",
  uxn = "uxntal",
  ts = "typescript",
}

local opts = { force = true, all = false }

---@param match table
---@param id integer
---@return TSNode|nil
local function get_node(match, id)
  local val = match[id]
  if not val then
    return nil
  end
  if type(val) == "table" and val.range then
    return val
  end
  if type(val) == "table" then
    return val[1]
  end
  return val
end

local function get_parser_from_markdown_info_string(injection_alias)
  local match = vim.filetype.match { filename = "a." .. injection_alias }
  return match or non_filetype_match_injection_language_aliases[injection_alias] or injection_alias
end

function M.patch()
  if patched or vim.fn.has "nvim-0.12" ~= 1 then
    return
  end

  local query = vim.treesitter.query

  query.add_predicate("nth?", function(match, _pattern, _bufnr, pred)
    local node = get_node(match, pred[2])
    local n = tonumber(pred[3])
    if node and node:parent() and node:parent():named_child_count() > n then
      return node:parent():named_child(n) == node
    end
    return false
  end, opts)

  query.add_predicate("is?", function(match, _pattern, bufnr, pred)
    local locals = require "nvim-treesitter.locals"
    local node = get_node(match, pred[2])
    local types = { unpack(pred, 3) }

    if not node then
      return true
    end

    local _, _, kind = locals.find_definition(node, bufnr)
    return vim.tbl_contains(types, kind)
  end, opts)

  query.add_predicate("kind-eq?", function(match, _pattern, _bufnr, pred)
    local node = get_node(match, pred[2])
    local types = { unpack(pred, 3) }

    if not node then
      return true
    end

    return vim.tbl_contains(types, node:type())
  end, opts)

  query.add_directive("set-lang-from-mimetype!", function(match, _, bufnr, pred, metadata)
    local node = get_node(match, pred[2])
    if not node then
      return
    end
    local type_attr_value = vim.treesitter.get_node_text(node, bufnr)
    local configured = html_script_type_languages[type_attr_value]
    if configured then
      metadata["injection.language"] = configured
    else
      local parts = vim.split(type_attr_value, "/", {})
      metadata["injection.language"] = parts[#parts]
    end
  end, opts)

  query.add_directive("set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
    local node = get_node(match, pred[2])
    if not node then
      return
    end
    local injection_alias = vim.treesitter.get_node_text(node, bufnr):lower()
    metadata["injection.language"] = get_parser_from_markdown_info_string(injection_alias)
  end, opts)

  query.add_directive("downcase!", function(match, _, bufnr, pred, metadata)
    local id = pred[2]
    local node = get_node(match, id)
    if not node then
      return
    end

    local text = vim.treesitter.get_node_text(node, bufnr, { metadata = metadata[id] }) or ""
    metadata[id] = metadata[id] or {}
    metadata[id].text = string.lower(text)
  end, opts)

  patched = true
end

return M

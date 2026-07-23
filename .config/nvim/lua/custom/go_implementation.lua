--- Go to implementation: symbol at cursor (or visual selection), then fuzzy picker.
--- gi: ripgrep + treesitter candidates (no LSP); Telescope fuzzy list.

local M = {}

local TS_DEFINE_TYPES = {
  function_definition = true,
  function_declaration = true,
  method_definition = true,
  method_declaration = true,
  class_definition = true,
  class_declaration = true,
  interface_declaration = true,
  type_definition = true,
  type_declaration = true,
  struct_item = true,
  impl_item = true,
  enum_item = true,
  enum_declaration = true,
  variable_declarator = true,
  lexical_declaration = true,
  const_declaration = true,
  field_definition = true,
  export_statement = true,
  function_item = true,
  local_function = true,
}

local function defining_name(node, bufnr)
  local name_node = node:child_by_field_name "name"
    or node:child_by_field_name "declarator"
    or node:named_child(0)
  while name_node do
    local t = name_node:type()
    if t == "identifier" or t == "property_identifier" or t == "type_identifier" then
      return vim.treesitter.get_node_text(name_node, bufnr)
    end
    if t == "function_declarator" or t == "pointer_declarator" then
      name_node = name_node:child_by_field_name "declarator" or name_node:named_child(0)
    else
      name_node = name_node:named_child(0)
    end
  end
  return nil
end

--- Symbol for gi: visual selection, enclosing TS definition name, else identifier/cword.
local function symbol_at_cursor()
  local mode = vim.fn.mode()
  if mode:find "[vV\022]" then
    local from = vim.fn.getpos "v"
    local to = vim.fn.getpos "."
    local lines = vim.api.nvim_buf_get_lines(0, from[2] - 1, to[2], false)
    if #lines > 0 then
      if from[2] == to[2] then
        lines[1] = lines[1]:sub(from[3], to[3])
      else
        lines[1] = lines[1]:sub(from[3])
        lines[#lines] = lines[#lines]:sub(1, to[3])
      end
      local text = vim.trim(table.concat(lines, " "))
      if text ~= "" then
        return text, nil
      end
    end
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local ok, node = pcall(vim.treesitter.get_node)
  if ok and node then
    local walk = node
    while walk do
      if TS_DEFINE_TYPES[walk:type()] then
        local name = defining_name(walk, bufnr)
        if name and name ~= "" then
          return name, walk
        end
      end
      walk = walk:parent()
    end
    walk = node
    while walk do
      local t = walk:type()
      if t == "identifier" or t == "property_identifier" or t == "type_identifier" or t == "field_identifier" then
        local text = vim.treesitter.get_node_text(walk, bufnr)
        if text and text ~= "" then
          return text, walk
        end
      end
      walk = walk:parent()
    end
  end
  return vim.fn.expand "<cword>", nil
end

local function current_win()
  return vim.api.nvim_get_current_win()
end

local function cursor_location()
  local win = current_win()
  local pos = vim.api.nvim_win_get_cursor(win)
  return {
    bufnr = vim.api.nvim_win_get_buf(win),
    filename = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)),
    lnum = pos[1],
    col = pos[2],
  }
end

---@param loc table
local function loc_key(loc)
  local file = loc.filename or vim.api.nvim_buf_get_name(loc.bufnr or -1)
  return string.format("%s:%d:%d", file, loc.lnum or 1, loc.col or 0)
end

local function same_position(a, b)
  if a.bufnr and b.bufnr and a.bufnr ~= b.bufnr then
    return false
  end
  local fa = a.filename or ""
  local fb = b.filename or ""
  if fa ~= "" and fb ~= "" and fa ~= fb then
    return false
  end
  return a.lnum == b.lnum and math.abs((a.col or 0) - (b.col or 0)) <= 1
end

local function add_location(locations, seen, loc)
  if not loc or not loc.lnum then
    return
  end
  loc.bufnr = loc.bufnr or vim.fn.bufnr(loc.filename, false)
  if loc.bufnr == -1 and loc.filename and loc.filename ~= "" then
    loc.bufnr = nil
  end
  local key = loc_key(loc)
  if seen[key] then
    return
  end
  seen[key] = true
  locations[#locations + 1] = loc
end

local function add_lsp_locations(out, seen, result, kind, enc)
  if not result then
    return
  end
  local list = vim.islist(result) and result or { result }
  local items = vim.lsp.util.locations_to_items(list, enc)
  for _, item in ipairs(items) do
    add_location(out, seen, {
      bufnr = item.bufnr,
      filename = item.filename,
      lnum = item.lnum,
      col = item.col,
      kind = kind,
      user_data = item.user_data,
      offset_encoding = enc,
    })
  end
end

local function sync_results(buf, method, params, timeout_ms)
  local raw = vim.lsp.buf_request_sync(buf, method, params, timeout_ms)
  if not raw then
    return {}
  end
  local merged = {}
  for _, response in pairs(raw) do
    if response.result then
      if vim.islist(response.result) then
        vim.list_extend(merged, response.result)
      else
        merged[#merged + 1] = response.result
      end
    end
  end
  return merged
end

local function workspace_root()
  local buf = vim.api.nvim_get_current_buf()
  for _, client in ipairs(vim.lsp.get_clients { bufnr = buf }) do
    local root = client.root_dir or (client.config and client.config.root_dir)
    if root and root ~= "" then
      return root
    end
  end

  local file = vim.api.nvim_buf_get_name(buf)
  local start = vim.fs.dirname(vim.loop.fs_realpath(file) or file)
  if not start or start == "" then
    return vim.loop.cwd()
  end

  local markers = { ".git", "buildServer.json", "Package.swift", "*.xcodeproj", "*.xcworkspace", "package.json", "go.mod", "Cargo.toml", "pyproject.toml" }
  local found = vim.fs.find(markers, { path = start, upward = true })[1]
  if found then
    return vim.fs.dirname(found)
  end

  return start
end

local function collect_lsp(sym, timeout_ms)
  local buf = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients { bufnr = buf }
  if #clients == 0 then
    return {}
  end
  local client = clients[1]
  local enc = client.offset_encoding
  -- First arg is window id, not bufnr (see vim.lsp.util.make_position_params).
  local pos_params = vim.lsp.util.make_position_params(0, enc)
  local doc_params = vim.lsp.util.make_text_document_params(buf)
  local out = {}
  local seen = {}

  if client:supports_method "textDocument/implementation" then
    add_lsp_locations(
      out,
      seen,
      sync_results(buf, "textDocument/implementation", pos_params, timeout_ms),
      "lsp-impl",
      enc
    )
  end

  if client:supports_method "textDocument/definition" then
    add_lsp_locations(
      out,
      seen,
      sync_results(buf, "textDocument/definition", pos_params, timeout_ms),
      "lsp-def",
      enc
    )
  end

  if client:supports_method "textDocument/documentSymbol" then
    local syms = sync_results(buf, "textDocument/documentSymbol", doc_params, timeout_ms)
    local uri = vim.uri_from_bufnr(buf)
    local function walk_symbol_list(slist)
      for _, s in ipairs(slist) do
        if s.name == sym then
          if s.location then
            add_lsp_locations(out, seen, s.location, "lsp-doc-symbol", enc)
          elseif s.range then
            add_lsp_locations(out, seen, { uri = uri, range = s.range }, "lsp-doc-symbol", enc)
          end
        end
        if s.children then
          walk_symbol_list(s.children)
        end
      end
    end
    walk_symbol_list(syms)
  end

  if client:supports_method "workspace/symbol" then
    local syms = sync_results(buf, "workspace/symbol", { query = sym }, timeout_ms)
    for _, s in ipairs(syms) do
      if s.name == sym and s.location then
        add_lsp_locations(out, seen, s.location, "lsp-workspace", enc)
      end
    end
  end

  return out
end

local function node_defines_symbol(node, bufnr, sym)
  if not TS_DEFINE_TYPES[node:type()] then
    return false
  end
  local name_node = node:child_by_field_name "name"
    or node:child_by_field_name "declarator"
    or node:named_child(0)
  while name_node do
    local t = name_node:type()
    if t == "identifier" or t == "property_identifier" or t == "type_identifier" then
      return vim.treesitter.get_node_text(name_node, bufnr) == sym
    end
    if t == "function_declarator" or t == "pointer_declarator" then
      name_node = name_node:child_by_field_name "declarator" or name_node:named_child(0)
    else
      name_node = name_node:named_child(0)
    end
  end
  return false
end

local function collect_treesitter(bufnr, sym)
  if not pcall(vim.treesitter.get_parser, bufnr) then
    return {}
  end
  local tree = vim.treesitter.get_parser(bufnr):trees()[1]
  if not tree then
    return {}
  end
  local out = {}
  local seen = {}

  local function walk(node)
    if node_defines_symbol(node, bufnr, sym) then
      local start_row, start_col = node:start()
      add_location(out, seen, {
        bufnr = bufnr,
        filename = vim.api.nvim_buf_get_name(bufnr),
        lnum = start_row + 1,
        col = start_col + 1,
        kind = "treesitter",
      })
    end
    for child in node:iter_children() do
      walk(child)
    end
  end

  walk(tree:root())
  return out
end

local function regex_escape(text)
  return (text:gsub("([%[%]%(%){}.*+?^$|\\%-])", "\\%1"))
end

local function lua_pattern_escape(text)
  return (text:gsub("([^%w])", "%%%1"))
end

local function collect_project_grep(sym)
  local root = workspace_root()
  local esc = regex_escape(sym)
  local patterns = {
    string.format("\\b(?:class|struct|actor|enum)\\s+\\w+[^\\n{]*:\\s*[^\\n{]*\\b%s\\b", esc),
    string.format("\\bextension\\s+\\w+[^\\n{]*:\\s*[^\\n{]*\\b%s\\b", esc),
    string.format("\\bextension\\s+%s\\b", esc),
    string.format("\\bfunc\\s+%s\\b", esc),
    string.format("\\b(?:class|struct|actor|enum|protocol)\\s+%s\\b", esc),
    string.format("\\b(?:let|var)\\s+%s\\b", esc),
    string.format("\\btypealias\\s+%s\\b", esc),
    string.format("\\bcase\\s+%s\\b", esc),
    string.format("\\bfunction\\s+%s\\s*[(=]", esc),
    string.format("\\bdef\\s+%s\\s*\\(", esc),
    string.format("\\bfun\\s+%s\\s*\\(", esc),
    string.format("\\bclass\\s+%s\\b", esc),
    string.format("\\binterface\\s+%s\\b", esc),
    string.format("\\btype\\s+%s\\b", esc),
    string.format("\\benum\\s+%s\\b", esc),
    string.format("\\b(?:const|let|var)\\s+%s\\b", esc),
    string.format("\\blocal\\s+function\\s+%s\\s*\\(", esc),
    string.format("\\bexport\\s+(?:default\\s+)?(?:async\\s+)?function\\s+%s\\b", esc),
    string.format("\\bexport\\s+(?:const|let|var|class|type|interface|enum)\\s+%s\\b", esc),
  }

  local args = { "rg", "--vimgrep", "--no-heading", "--smart-case", "-g", "!.git", "-g", "!node_modules" }
  for _, p in ipairs(patterns) do
    args[#args + 1] = "-e"
    args[#args + 1] = p
  end
  args[#args + 1] = root

  local result = vim.system(args, { text = true, timeout = 3000 }):wait()
  if result.code ~= 0 or not result.stdout or result.stdout == "" then
    return {}
  end

  local out = {}
  local seen = {}
  for line in result.stdout:gmatch "[^\n]+" do
    local file, lnum, col, text = line:match "^(.-):(%d+):(%d+):(.*)$"
    if file and lnum then
      add_location(out, seen, {
        filename = file,
        lnum = tonumber(lnum),
        col = tonumber(col) or 1,
        kind = "grep",
        preview = text,
      })
    end
  end
  return out
end

local function preview_line(loc)
  if loc.preview then
    return loc.preview
  end
  local bufnr = loc.bufnr
  if not bufnr or bufnr == -1 then
    bufnr = vim.fn.bufnr(loc.filename, false)
  end
  if bufnr and bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    local lines = vim.api.nvim_buf_get_lines(bufnr, loc.lnum - 1, loc.lnum, false)
    return lines[1] or ""
  end
  if loc.filename and loc.filename ~= "" then
    local ok, lines = pcall(vim.fn.readfile, loc.filename, "", loc.lnum)
    if ok and lines then
      return lines[loc.lnum] or ""
    end
  end
  return ""
end

local function read_location_lines(loc, first, last)
  first = math.max(first, 1)
  last = math.max(last, first)

  local bufnr = loc.bufnr
  if bufnr and bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    return vim.api.nvim_buf_get_lines(bufnr, first - 1, last, false)
  end

  if not loc.filename or loc.filename == "" then
    return {}
  end

  local ok, lines = pcall(vim.fn.readfile, loc.filename, "", last)
  if not ok or not lines then
    return {}
  end

  local out = {}
  for i = first, last do
    out[#out + 1] = lines[i] or ""
  end
  return out
end

local function swift_scope_before(loc)
  local lines = read_location_lines(loc, math.max(1, loc.lnum - 250), loc.lnum)
  for i = #lines, 1, -1 do
    local line = lines[i]:gsub("//.*", "")
    for _, kind in ipairs { "protocol", "extension", "struct", "actor", "enum", "class" } do
      local name = line:match("^%s*[%w_@%s]*" .. kind .. "%s+([%w_]+)")
      if name and not (kind == "class" and (name == "func" or name == "var")) then
        return kind
      end
    end
  end
  return nil
end

local function swift_line_has_symbol_decl(line, sym, keyword)
  local pat = lua_pattern_escape(sym)
  return line:match("%f[%w_]" .. keyword .. "%s+" .. pat .. "%f[^%w_]") ~= nil
end

local function swift_line_has_conformance(line, sym)
  local pat = lua_pattern_escape(sym)
  for _, kind in ipairs { "class", "struct", "actor", "enum" } do
    if line:match("%f[%w_]" .. kind .. "%s+[%w_]+[^\n{]*:%s*[^\n{]*%f[%w_]" .. pat .. "%f[^%w_]") then
      return true
    end
  end
  return line:match("%f[%w_]extension%s+[%w_%.]+[^\n{]*:%s*[^\n{]*%f[%w_]" .. pat .. "%f[^%w_]") ~= nil
end

local function location_looks_like_implementation(loc, sym)
  local filename = loc.filename
  if (not filename or filename == "") and loc.bufnr and loc.bufnr ~= -1 then
    filename = vim.api.nvim_buf_get_name(loc.bufnr)
  end
  filename = filename or ""
  if not filename:match "%.swift$" then
    return true
  end

  local line = preview_line(loc):gsub("//.*", "")
  if line == "" then
    return false
  end

  if swift_line_has_conformance(line, sym) then
    return true
  end

  local scope = swift_scope_before(loc)
  if swift_line_has_symbol_decl(line, sym, "protocol") then
    return false
  end

  for _, keyword in ipairs { "func", "var", "let", "case", "typealias", "extension", "class", "struct", "actor", "enum" } do
    if swift_line_has_symbol_decl(line, sym, keyword) then
      return scope ~= "protocol"
    end
  end

  return false
end

--- Open a location in the current (or given) window.
---@param loc table
---@param opts? { win?: integer, offset_encoding?: string }
function M.jump_to(loc, opts)
  opts = opts or {}
  if opts.win and vim.api.nvim_win_is_valid(opts.win) then
    vim.api.nvim_set_current_win(opts.win)
  end

  if loc.user_data then
    local enc = loc.offset_encoding or opts.offset_encoding or "utf-16"
    vim.lsp.util.show_document(loc.user_data, enc, { focus = true })
    return
  end

  local fname = loc.filename
  if not fname or fname == "" then
    return
  end

  local bufnr = vim.fn.bufnr(fname, true)
  if bufnr == -1 then
    vim.cmd("edit " .. vim.fn.fnameescape(fname))
  else
    vim.api.nvim_win_set_buf(current_win(), bufnr)
  end
  vim.fn.cursor(loc.lnum, loc.col or 1)
  vim.cmd "normal! zz"
end

--- Sync LSP definition quickfix items for `buf` (includes `user_data` for jumps).
---@return vim.quickfix.entry[], string|nil offset_encoding
function M.definition_items(buf)
  local clients = vim.lsp.get_clients { bufnr = buf }
  if #clients == 0 then
    return {}, nil
  end
  local client = clients[1]
  local enc = client.offset_encoding
  local raw = vim.lsp.buf_request_sync(
    buf,
    "textDocument/definition",
    vim.lsp.util.make_position_params(0, enc),
    2500
  )
  if not raw then
    return {}, enc
  end
  local items = {}
  for _, r in pairs(raw) do
    if r.result then
      local list = vim.islist(r.result) and r.result or { r.result }
      vim.list_extend(items, vim.lsp.util.locations_to_items(list, enc))
    end
  end
  return items, enc
end

local jump_to = M.jump_to

local function show_picker(locations, sym)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"

  pickers
    .new({}, {
      prompt_title = "Implementation · " .. sym,
      finder = finders.new_table {
        results = locations,
        entry_maker = function(entry)
          local file = vim.fn.fnamemodify(entry.filename or "", ":~:.")
          local line = preview_line(entry)
          line = vim.trim(line):sub(1, 80)
          return {
            value = entry,
            path = entry.filename,
            filename = entry.filename,
            bufnr = entry.bufnr,
            lnum = entry.lnum,
            col = entry.col or 0,
            display = string.format("%s:%d:%d [%s] %s", file, entry.lnum, (entry.col or 0) + 1, entry.kind or "?", line),
            ordinal = table.concat { file, entry.kind, line },
          }
        end,
      },
      sorter = conf.generic_sorter {},
      previewer = conf.grep_previewer {},
      attach_mappings = function(_, map)
        actions.select_default:replace(function(prompt_bufnr)
          actions.close(prompt_bufnr)
          local entry = action_state.get_selected_entry()
          if entry then
            local loc = entry.value
            jump_to(loc, loc.offset_encoding and { offset_encoding = loc.offset_encoding } or nil)
          end
        end)
        return true
      end,
    })
    :find()
end

local function apply_cursor_filter(all, cur)
  local filtered = {}
  for _, loc in ipairs(all) do
    if not same_position(loc, cur) then
      filtered[#filtered + 1] = loc
    end
  end
  local used_unfiltered_fallback = false
  if #filtered == 0 and #all > 0 then
    filtered = all
    used_unfiltered_fallback = true
  end
  return filtered, used_unfiltered_fallback
end

local function filter_current_location(all, cur)
  local filtered = {}
  for _, loc in ipairs(all) do
    if not same_position(loc, cur) then
      filtered[#filtered + 1] = loc
    end
  end
  return filtered
end

--- LSP-only collection (fast path for definition-side fallbacks).
function M.lsp_locations(sym, opts)
  opts = opts or {}
  local cur = cursor_location()
  local all = collect_lsp(sym, opts.lsp_timeout or 2500)
  local filtered, used_unfiltered_fallback = apply_cursor_filter(all, cur)
  return filtered, cur, all, used_unfiltered_fallback
end

function M.implementation_locations(sym, opts)
  opts = opts or {}
  sym = sym or symbol_at_cursor()
  local cur = cursor_location()
  local all = {}
  local seen = {}

  pcall(function()
    for _, loc in ipairs(collect_treesitter(cur.bufnr, sym)) do
      add_location(all, seen, loc)
    end
  end)
  pcall(function()
    for _, loc in ipairs(collect_project_grep(sym)) do
      add_location(all, seen, loc)
    end
  end)

  local filtered = {}
  for _, loc in ipairs(all) do
    if not same_position(loc, cur) and location_looks_like_implementation(loc, sym) then
      filtered[#filtered + 1] = loc
    end
  end

  return filtered, cur, all
end

function M.collect_all(sym, opts)
  opts = opts or {}
  local timeout = opts.lsp_timeout or 2500
  local cur = cursor_location()
  local seen = {}
  local all = {}

  for _, loc in ipairs(collect_lsp(sym, timeout)) do
    add_location(all, seen, loc)
  end
  local cur_buf = vim.api.nvim_get_current_buf()
  pcall(function()
    for _, loc in ipairs(collect_treesitter(cur_buf, sym)) do
      add_location(all, seen, loc)
    end
  end)

  -- Project grep is slow on large trees; only run when LSP + buffer TS found nothing.
  if #all == 0 then
    pcall(function()
      for _, loc in ipairs(collect_project_grep(sym)) do
        add_location(all, seen, loc)
      end
    end)
  end

  local filtered = apply_cursor_filter(all, cur)
  return filtered, cur, all
end

function M.go()
  if type(vim.t.bufs) == "table" then
    vim.t.bufs = vim.tbl_filter(function(b)
      return type(b) == "number" and vim.api.nvim_buf_is_valid(b)
    end, vim.t.bufs)
  end

  local sym = symbol_at_cursor()
  if not sym or sym == "" then
    vim.notify("No symbol under cursor", vim.log.levels.WARN)
    return
  end

  local locations, _, all = M.implementation_locations(sym)
  if #locations == 0 then
    if #all > 0 then
      vim.notify(("No implementations for %q outside the current location"):format(sym), vim.log.levels.INFO)
    else
      vim.notify(("No implementations for %q"):format(sym), vim.log.levels.INFO)
    end
    return
  end

  show_picker(locations, sym)
end

return M

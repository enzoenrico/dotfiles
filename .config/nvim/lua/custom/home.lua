--- Grok-style start screen: fastfetch animation, recent files, actions.
--- Opens on a bare `nvim`. `:Home` brings it back. Pickers stay on Snacks.
--- The buffer is a plain read-only buffer: no input bar, no key capture. Every
--- normal keybind works; j/k hop between rows and <CR> opens the row.
--- The hero is the anifetch clip (see custom/home_anim.lua).

local M = {}

local anim = require "custom.home_anim"

local ACTIONS = {
  { id = "files", key = "SPC ff", label = "Find file" },
  { id = "grep", key = "SPC fw", label = "Find text" },
  { id = "recent", key = "", label = "Recent files" },
  { id = "tree", key = "SPC E", label = "File sidebar" },
  { id = "new", key = ":enew", label = "New file" },
  { id = "config", key = "", label = "Config" },
  { id = "quit", key = ":qa", label = "Quit" },
}

local ns = vim.api.nvim_create_namespace "nvim_home"
local ns_logo = vim.api.nvim_create_namespace "nvim_home_logo"

local state = {
  open = false,
  tick = 0,
  selected = 1,
  reduce_motion = false,
  forcing = false,
}

local render_full
local refresh
local tick
local place_cursor
local activate

local function strwidth(text)
  return vim.fn.strwidth(text)
end

local function chars_of(text)
  local out = {}
  for ch in text:gmatch "[%z\1-\127\194-\244][\128-\191]*" do
    out[#out + 1] = ch
  end
  return out
end

local function fit_end(text, max)
  if strwidth(text) <= max then
    return text
  end
  if max <= 1 then
    return "…"
  end
  local chars = chars_of(text)
  local acc = {}
  local width = 0
  for i = #chars, 1, -1 do
    local cw = strwidth(chars[i])
    if width + cw > max - 1 then
      break
    end
    table.insert(acc, 1, chars[i])
    width = width + cw
  end
  return "…" .. table.concat(acc)
end

local function spans_width(spans)
  local width = 0
  for _, span in ipairs(spans) do
    width = width + strwidth(span.text or "")
  end
  return width
end

local function flatten(spans)
  local parts = {}
  local ranges = {}
  local byte = 0
  local cursor_byte
  for _, span in ipairs(spans) do
    local text = span.text or ""
    if text ~= "" then
      parts[#parts + 1] = text
      if span.hl then
        ranges[#ranges + 1] = { span.hl, byte, byte + #text }
      end
      byte = byte + #text
    end
    if span.cursor_after then
      cursor_byte = byte
    end
  end
  return table.concat(parts), ranges, cursor_byte
end

local function mix(a, b, t)
  local function channel(hex, i)
    return tonumber(hex:sub(i, i + 1), 16)
  end
  local function byte(n)
    return string.format("%02x", math.max(0, math.min(255, math.floor(n + 0.5))))
  end
  return string.format(
    "#%s%s%s",
    byte(channel(a, 2) + (channel(b, 2) - channel(a, 2)) * t),
    byte(channel(a, 4) + (channel(b, 4) - channel(a, 4)) * t),
    byte(channel(a, 6) + (channel(b, 6) - channel(a, 6)) * t)
  )
end

local function palette()
  if vim.o.background == "light" then
    return {
      text = "#1C1B1F",
      dim = "#6E6C73",
      accent = "#D31266",
      border = "#C8C6CC",
      border_focus = "#1C1B1F",
      selected = "#F6E8EE",
      trough = "#8A8490",
      peak = "#8E0E45",
    }
  end
  return {
    text = "#E8E6E3",
    dim = "#8E8C93",
    accent = "#FF4B8B",
    border = "#3E3E46",
    border_focus = "#E4E4E8",
    selected = "#2A2428",
    trough = "#6E6870",
    peak = "#FFF1F6",
  }
end

function M.apply_highlights()
  local pal = palette()
  local function set(name, opts)
    opts.default = false
    vim.api.nvim_set_hl(0, name, opts)
  end

  set("HomeText", { fg = pal.text })
  set("HomeDim", { fg = pal.dim })
  set("HomeAccent", { fg = pal.accent, bold = true })
  set("HomeBorder", { fg = pal.border })
  set("HomeBorderFocus", { fg = pal.border_focus })
  set("HomeSelectedText", { fg = pal.text, bg = pal.selected, bold = true })
  set("HomeSelectedDim", { fg = pal.dim, bg = pal.selected })
  set("HomeSelectedAccent", { fg = pal.accent, bg = pal.selected, bold = true })
  set("HomeTrail1", { fg = mix(pal.accent, pal.peak, 0.45) })
  set("HomeTrail2", { fg = mix(pal.trough, pal.accent, 0.55) })
  anim.apply_highlights()
end

local glyphs
local function marks()
  if glyphs then
    return glyphs
  end
  local function pick(fancy, plain)
    if strwidth(fancy) == 1 then
      return fancy
    end
    return plain
  end
  local rounded = strwidth "╭" == 1 and strwidth "─" == 1 and strwidth "│" == 1
  glyphs = {
    head = pick("●", "*"),
    mid = pick("•", "o"),
    dot = pick("·", "."),
    bullet = pick("◆", "*"),
    box = rounded and {
      tl = "╭",
      tr = "╮",
      bl = "╰",
      br = "╯",
      h = "─",
      v = "│",
    } or {
      tl = "+",
      tr = "+",
      bl = "+",
      br = "+",
      h = "-",
      v = "|",
    },
  }
  return glyphs
end

local function place(spans, left, win_w)
  local out = {}
  if left > 0 then
    out[#out + 1] = { text = string.rep(" ", left) }
  end
  for _, span in ipairs(spans) do
    out[#out + 1] = span
  end
  local right = win_w - left - spans_width(spans)
  if right > 0 then
    out[#out + 1] = { text = string.rep(" ", right) }
  end
  return out
end

local function center(spans, width)
  local left = math.max(0, math.floor((width - spans_width(spans)) / 2))
  return place(spans, left, width)
end

local function orbit_spans(frame, content_w, rows)
  local g = marks()
  rows = rows or 7
  local cols = math.min(33, content_w)
  if cols % 2 == 0 then
    cols = cols - 1
  end
  if cols < 15 or rows < 5 then
    return nil
  end

  local grid = {}
  for y = 1, rows do
    grid[y] = {}
    for x = 1, cols do
      grid[y][x] = { ch = " ", hl = nil, prio = -1 }
    end
  end

  local function plot(x, y, ch, hl, prio)
    local cx = math.floor(x + 0.5)
    local cy = math.floor(y + 0.5)
    if cy < 1 or cy > rows or cx < 1 or cx > cols then
      return
    end
    local cell = grid[cy][cx]
    if prio >= cell.prio then
      cell.ch = ch
      cell.hl = hl
      cell.prio = prio
    end
  end

  local cx = (cols + 1) / 2
  local cy = (rows + 1) / 2
  local rx = (cols - 5) / 2
  local ry = (rows - 1) / 2
  -- One ring. Eight points stay readable on a short grid; the head walks it.
  local count = 8
  for i = 0, count - 1 do
    local ang = -frame * 0.35 + i * (2 * math.pi / count)
    local x = cx + math.cos(ang) * rx
    local y = cy + math.sin(ang) * ry
    local ch, hl, prio
    if i == 0 then
      ch, hl, prio = g.head, "HomeAccent", 3
    elseif i == 1 or i == count - 1 then
      ch, hl, prio = g.mid, "HomeTrail1", 2
    elseif i == 2 or i == count - 2 then
      ch, hl, prio = g.dot, "HomeTrail2", 1
    else
      ch, hl, prio = g.dot, "HomeDim", 0
    end
    plot(x, y, ch, hl, prio)
  end
  plot(cx, cy, g.bullet, "HomeAccent", 4)

  local lines = {}
  for y = 1, rows do
    local spans = {}
    local run_hl, run = nil, ""
    local function flush()
      if run ~= "" then
        spans[#spans + 1] = { text = run, hl = run_hl }
        run = ""
        run_hl = nil
      end
    end
    for x = 1, cols do
      local cell = grid[y][x]
      if cell.hl ~= run_hl then
        flush()
        run_hl = cell.hl
      end
      run = run .. cell.ch
    end
    flush()
    lines[#lines + 1] = center(spans, content_w)
  end
  return lines
end

local function section_header(title, content_w)
  local box = marks().box
  local label = "  " .. title
  local dashes = math.max(1, content_w - strwidth(label) - 1)
  return {
    { text = label, hl = "HomeDim" },
    { text = " " .. string.rep(box.h, dashes), hl = "HomeBorder" },
  }
end

local function row_spans(item, content_w, selected)
  local g = marks()
  local meta_w = 3
  local meta = item.meta or ""
  if strwidth(meta) > meta_w then
    meta = fit_end(meta, meta_w)
  end
  meta = string.rep(" ", meta_w - strwidth(meta)) .. meta
  local key = item.key or ""
  local key_w = 6
  key = string.rep(" ", math.max(0, key_w - strwidth(key))) .. key
  local right_w = meta_w + 2 + key_w
  local prefix = "  " .. g.bullet .. "  "
  local label_max = content_w - strwidth(prefix) - right_w
  local label = item.tail and fit_end(item.label, label_max) or item.label
  if strwidth(label) > label_max then
    label = fit_end(label, math.max(1, label_max))
  end
  local gap = content_w - strwidth(prefix) - strwidth(label) - right_w
  if gap < 0 then
    gap = 0
  end

  local text_hl = selected and "HomeSelectedText" or "HomeText"
  local dim_hl = selected and "HomeSelectedDim" or "HomeDim"
  local accent_hl = selected and "HomeSelectedAccent" or "HomeAccent"
  local bullet_hl = selected and "HomeSelectedAccent" or "HomeDim"
  local fill_hl = selected and "HomeSelectedText" or nil

  return {
    { text = "  ", hl = fill_hl },
    { text = g.bullet, hl = bullet_hl },
    { text = "  ", hl = fill_hl },
    { text = label, hl = text_hl },
    { text = string.rep(" ", gap), hl = fill_hl },
    { text = meta, hl = dim_hl },
    { text = "  ", hl = fill_hl },
    { text = key, hl = dim_hl },
  }
end

local function subtitle_spans(view, content_w)
  local cwd = vim.fn.fnamemodify(view.cwd, ":~")
  local parts = {
    { text = cwd, hl = "HomeDim" },
  }
  if view.branch and view.branch ~= "" then
    parts[#parts + 1] = { text = "  ·  ", hl = "HomeBorder" }
    parts[#parts + 1] = { text = view.branch, hl = "HomeAccent" }
  end
  parts[#parts + 1] = { text = "  ·  ", hl = "HomeBorder" }
  parts[#parts + 1] = { text = view.version, hl = "HomeDim" }
  if view.startup_ms and view.startup_ms > 0 then
    parts[#parts + 1] = { text = "  ·  ", hl = "HomeBorder" }
    parts[#parts + 1] = { text = view.startup_ms .. "ms", hl = "HomeDim" }
  end
  local width = spans_width(parts)
  if width <= content_w then
    return center(parts, content_w)
  end
  local short = {
    { text = vim.fn.fnamemodify(view.cwd, ":t"), hl = "HomeDim" },
  }
  if view.branch and view.branch ~= "" then
    short[#short + 1] = { text = "  ·  ", hl = "HomeBorder" }
    short[#short + 1] = { text = view.branch, hl = "HomeAccent" }
  end
  return center(short, content_w)
end

local function filtered_items(view)
  return view.recents or {}, ACTIONS
end

local function compose(view, spec, recents, actions)
  local content_w = spec.content_w
  local body = {}
  local function add(spans, kind)
    body[#body + 1] = { spans = spans, kind = kind }
  end
  local function blank()
    body[#body + 1] = { spans = {} }
  end

  if spec.orbit then
    local cols = anim.cols_for(spec.orbit_rows, content_w)
    spec.anim_cols = cols
    local drew = false
    if cols and not anim.absent() then
      local frame = anim.frame(view.tick or 0, cols, spec.orbit_rows)
      if frame then
        for _, spans in ipairs(frame) do
          add(center(spans, content_w), "orbit")
        end
      else
        for _ = 1, spec.orbit_rows do
          add({}, "orbit")
        end
      end
      drew = true
    end
    if not drew then
      local rows = orbit_spans(view.tick or 0, content_w, spec.orbit_rows)
      if rows then
        for _, spans in ipairs(rows) do
          add(spans, "orbit")
        end
        drew = true
      end
    end
    if drew then
      blank()
    end
  end

  if spec.subtitle then
    blank()
    add(subtitle_spans(view, content_w))
  end

  local shown_recent = {}
  for i = 1, math.min(spec.recent_n, #recents) do
    shown_recent[i] = recents[i]
  end

  local action_set = {}
  for _, id in ipairs(spec.action_ids) do
    action_set[id] = true
  end
  local shown_actions = {}
  for _, action in ipairs(actions) do
    if action_set[action.id] then
      shown_actions[#shown_actions + 1] = action
    end
  end

  local entries = {}
  for i, recent in ipairs(shown_recent) do
    entries[#entries + 1] = {
      id = "edit",
      key = "",
      label = recent.label,
      meta = recent.meta,
      path = recent.path,
      tail = true,
    }
  end
  for _, action in ipairs(shown_actions) do
    entries[#entries + 1] = {
      id = action.id,
      key = action.key,
      label = action.label,
      meta = "",
      tail = false,
    }
  end

  local selected = tonumber(view.selected) or 1
  if #entries == 0 then
    selected = 1
  else
    selected = math.max(1, math.min(#entries, selected))
  end

  if #shown_recent > 0 then
    blank()
    if spec.headers then
      add(section_header("Recent", content_w))
    end
  end

  local recent_count = #shown_recent
  for i, entry in ipairs(entries) do
    if i == recent_count + 1 then
      blank()
      if spec.headers then
        add(section_header("Actions", content_w))
      end
    end
    local item = {
      id = entry.id,
      key = entry.key,
      path = entry.path,
      label = entry.label,
    }
    body[#body + 1] = {
      spans = row_spans(entry, content_w, i == selected),
      item = item,
    }
  end

  return body, selected
end

--- Build the screen for a window size. Pure aside from strwidth and highlights.
function M.layout(view)
  local width = math.max(1, view.width or 80)
  local height = math.max(1, view.height or 24)
  local content_w = math.min(72, width - 4)
  if content_w < 24 then
    content_w = math.max(8, width - 2)
  end
  local left = math.max(0, math.floor((width - content_w) / 2))
  local recents, actions = filtered_items(view)

  local body_h = height

  local spec = {
    content_w = content_w,
    orbit = content_w >= 36,
    orbit_rows = 12,
    subtitle = true,
    headers = true,
    recent_n = 5,
    action_ids = { "files", "grep", "recent", "tree", "new", "config", "quit" },
  }
  if not spec.orbit then
    spec.orbit = false
  end

  local steps = {
    function(s)
      s.recent_n = 3
    end,
    function(s)
      if s.orbit_rows > 8 then
        s.orbit_rows = 8
      end
    end,
    function(s)
      if s.orbit_rows > 6 then
        s.orbit_rows = 6
      end
    end,
    function(s)
      s.recent_n = 1
    end,
    function(s)
      s.subtitle = false
      s.headers = false
    end,
    function(s)
      s.recent_n = 0
    end,
    function(s)
      s.orbit = false
    end,
    function(s)
      s.action_ids = { "files", "grep", "new", "quit" }
    end,
  }

  local body, selected = compose(view, spec, recents, actions)
  for _, step in ipairs(steps) do
    if #body <= body_h then
      break
    end
    step(spec)
    body, selected = compose(view, spec, recents, actions)
  end
  while #body > body_h and #body > 0 do
    table.remove(body)
  end

  local pad = math.max(0, body_h - #body)
  local top_pad = math.floor(pad / 2)
  local bottom_pad = pad - top_pad

  local span_lines = {}
  local logo = {}
  local items = {}
  local function push(spans, kind, item)
    if left > 0 or spans_width(spans) ~= width then
      spans = place(spans, left, width)
    end
    span_lines[#span_lines + 1] = spans
    if kind then
      logo[#span_lines] = kind
    end
    if item then
      item.line = #span_lines
      item.col = left + 2
      items[#items + 1] = item
    end
  end
  local function push_blank()
    span_lines[#span_lines + 1] = {}
  end

  for _ = 1, top_pad do
    push_blank()
  end
  for _, row in ipairs(body) do
    push(row.spans, row.kind, row.item)
  end
  for _ = 1, bottom_pad do
    push_blank()
  end

  while #span_lines < height do
    span_lines[#span_lines + 1] = {}
  end
  while #span_lines > height do
    table.remove(span_lines)
  end

  return {
    span_lines = span_lines,
    items = items,
    selected = selected,
    logo = logo,
    content_w = content_w,
    anim = spec.orbit and spec.anim_cols and { cols = spec.anim_cols, rows = spec.orbit_rows } or nil,
  }
end

local function version_label()
  local v = vim.version()
  return string.format("NVIM %d.%d.%d", v.major, v.minor, v.patch)
end

local function ignored_path(path)
  local norm = vim.fs.normalize(path)
  for _, name in ipairs { "data", "cache", "state" } do
    local root = vim.fs.normalize(vim.fn.stdpath(name))
    if norm == root or norm:sub(1, #root + 1) == root .. "/" then
      return true
    end
  end
  return false
end

local function display_path(path, cwd)
  local norm = vim.fs.normalize(path)
  local root = vim.fs.normalize(cwd)
  if norm:sub(1, #root) == root then
    local rest = norm:sub(#root + 1)
    if rest == "" then
      return vim.fn.fnamemodify(path, ":t")
    end
    if rest:sub(1, 1) == "/" then
      rest = rest:sub(2)
      if rest ~= "" then
        return rest
      end
    end
  end
  return vim.fn.fnamemodify(path, ":~")
end

local function age_of(path)
  local mtime = vim.fn.getftime(path)
  if type(mtime) ~= "number" or mtime < 0 then
    return ""
  end
  local delta = os.time() - mtime
  if delta < 45 then
    return "now"
  end
  if delta < 3600 then
    return math.max(1, math.floor(delta / 60)) .. "m"
  end
  if delta < 86400 then
    return math.floor(delta / 3600) .. "h"
  end
  if delta < 86400 * 14 then
    return math.floor(delta / 86400) .. "d"
  end
  if delta < 86400 * 70 then
    return math.max(1, math.floor(delta / (86400 * 7))) .. "w"
  end
  return math.max(1, math.floor(delta / (86400 * 365))) .. "y"
end

local function collect_recents(cwd, limit)
  local seen = {}
  local in_cwd = {}
  local other = {}
  local root = vim.fs.normalize(cwd)
  for _, path in ipairs(vim.v.oldfiles or {}) do
    if path ~= "" and not seen[path] and not ignored_path(path) then
      seen[path] = true
      local stat = vim.uv.fs_stat(path)
      if stat and stat.type == "file" then
        local item = {
          path = path,
          label = display_path(path, cwd),
          meta = age_of(path),
        }
        local norm = vim.fs.normalize(path)
        if norm:sub(1, #root + 1) == root .. "/" then
          in_cwd[#in_cwd + 1] = item
        else
          other[#other + 1] = item
        end
      end
    end
    if #in_cwd >= limit then
      break
    end
  end
  local out = in_cwd
  if #out < limit then
    for _, item in ipairs(other) do
      out[#out + 1] = item
      if #out >= limit then
        break
      end
    end
  end
  return out
end

local function view_of()
  return {
    width = vim.api.nvim_win_get_width(state.win),
    height = vim.api.nvim_win_get_height(state.win),
    tick = state.tick,
    selected = state.selected,
    cwd = vim.fn.getcwd(),
    branch = state.branch,
    version = version_label(),
    startup_ms = state.startup_ms,
    recents = state.recents or {},
  }
end

local function paint(buf, hl_ns, row, line_ranges)
  for _, range in ipairs(line_ranges) do
    if range[3] > range[2] then
      vim.api.nvim_buf_set_extmark(buf, hl_ns, row, range[2], {
        end_col = range[3],
        hl_group = range[1],
        strict = false,
      })
    end
  end
end

local function apply_layout(laid, logo_only)
  local buf = state.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local texts = {}
  local ranges = {}
  for i, spans in ipairs(laid.span_lines) do
    local text, line_ranges = flatten(spans)
    texts[i] = text
    ranges[i] = line_ranges
  end

  local orbit_start, orbit_end, orbit_n = nil, nil, 0
  for i, kind in pairs(laid.logo) do
    if kind == "orbit" then
      orbit_n = orbit_n + 1
      orbit_start = orbit_start and math.min(orbit_start, i) or i
      orbit_end = orbit_end and math.max(orbit_end, i) or i
    end
  end
  local orbit_dense = orbit_start ~= nil and (orbit_end - orbit_start + 1 == orbit_n)

  vim.bo[buf].modifiable = true
  if logo_only and orbit_dense then
    local chunk = {}
    for n = orbit_start, orbit_end do
      chunk[#chunk + 1] = texts[n]
    end
    vim.api.nvim_buf_set_lines(buf, orbit_start - 1, orbit_end, false, chunk)
  elseif not (logo_only and orbit_n == 0) then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, texts)
    logo_only = false
  end
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  if logo_only then
    vim.api.nvim_buf_clear_namespace(buf, ns_logo, 0, -1)
    for i, line_ranges in ipairs(ranges) do
      if laid.logo[i] then
        paint(buf, ns_logo, i - 1, line_ranges)
      end
    end
  else
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, ns_logo, 0, -1)
    for i, line_ranges in ipairs(ranges) do
      paint(buf, laid.logo[i] and ns_logo or ns, i - 1, line_ranges)
    end
  end

  state.laid = laid
  state.items = laid.items
  state.selected = laid.selected
  if not logo_only then
    place_cursor()
  end
end

render_full = function()
  if not state.open or not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  state.recents = collect_recents(vim.fn.getcwd(), 8)
  local laid = M.layout(view_of())
  if laid.anim and anim.warm(laid.anim.cols, laid.anim.rows) then
    laid = M.layout(view_of())
  end
  apply_layout(laid, false)
  if laid.anim and not anim.frame(0, laid.anim.cols, laid.anim.rows) and not anim.absent() then
    anim.ensure(laid.anim.cols, laid.anim.rows, function()
      if state.open then
        render_full()
      end
    end)
  end
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    state.laid_width = vim.api.nvim_win_get_width(state.win)
    state.laid_height = vim.api.nvim_win_get_height(state.win)
  end
end

tick = function()
  if not state.open or state.reduce_motion then
    return
  end
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  local width = vim.api.nvim_win_get_width(state.win)
  local height = vim.api.nvim_win_get_height(state.win)
  if not state.laid or width ~= state.laid_width or height ~= state.laid_height then
    render_full()
    state.laid_width = width
    state.laid_height = height
    return
  end
  state.tick = state.tick + 1
  local laid = M.layout(view_of())
  apply_layout(laid, true)
end

place_cursor = function()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  local item = state.items and state.items[state.selected]
  if not item then
    return
  end
  state.placing = true
  pcall(vim.api.nvim_win_set_cursor, state.win, { item.line, item.col })
  state.cursor_line = item.line
  if vim.api.nvim_get_current_win() == state.win then
    pcall(vim.fn.winrestview, { topline = 1, leftcol = 0 })
  end
  state.placing = false
end

--- Re-render rows after the selection moved. Skips the recents scan and the clip.
refresh = function()
  if not state.open or not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  apply_layout(M.layout(view_of()), false)
end

local function hide_chrome()
  state.solo = true
  if vim.o.laststatus ~= 0 then
    state.want_laststatus = vim.o.laststatus
  end
  if vim.o.showtabline ~= 0 then
    state.want_showtabline = vim.o.showtabline
  end
  state.forcing = true
  vim.o.laststatus = 0
  vim.o.showtabline = 0
  state.forcing = false
end

local function show_chrome()
  state.solo = false
  local laststatus = state.want_laststatus
  if not laststatus or laststatus == 0 then
    laststatus = package.loaded.lualine and 3 or 2
  end
  local showtabline = state.want_showtabline
  if not showtabline or showtabline == 0 then
    showtabline = package.loaded.bufferline and 2 or 1
  end
  state.forcing = true
  vim.o.laststatus = laststatus
  vim.o.showtabline = showtabline
  state.forcing = false
end

local function nonfloat_count()
  local count = 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      count = count + 1
    end
  end
  return count
end

local function sync_chrome()
  if not state.open then
    return
  end
  if nonfloat_count() <= 1 then
    hide_chrome()
  else
    show_chrome()
  end
end

local function stop_timer()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
end

local function start_timer()
  if state.reduce_motion or state.timer then
    return
  end
  state.timer = vim.uv.new_timer()
  state.timer:start(100, 100, function()
    if state.ticking then
      return
    end
    state.ticking = true
    vim.schedule(function()
      state.ticking = false
      pcall(tick)
    end)
  end)
end

local function close()
  if not state.open then
    return
  end
  state.open = false
  stop_timer()
  show_chrome()
  state.buf = nil
  state.win = nil
  state.laid = nil
end

local function pick(cmd, opts)
  local ok, err = pcall(function()
    Snacks.dashboard.pick(cmd, opts)
  end)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.ERROR, { title = "Home" })
  end
end

local actions = {
  files = function()
    pick "files"
  end,
  grep = function()
    pick "live_grep"
  end,
  recent = function()
    pick "oldfiles"
  end,
  tree = function()
    local ok, err = pcall(function()
      local picker = Snacks.explorer.reveal()
      if picker and picker.focus then
        picker:focus()
      end
    end)
    if not ok then
      vim.notify(tostring(err), vim.log.levels.ERROR, { title = "Home" })
    end
  end,
  new = function()
    vim.cmd "enew"
    vim.cmd "startinsert"
  end,
  config = function()
    pick("files", { cwd = vim.fn.stdpath "config" })
  end,
  quit = function()
    vim.cmd "qa"
  end,
  edit = function(item)
    vim.cmd { cmd = "edit", args = { item.path } }
  end,
}

activate = function()
  local item = state.items and state.items[state.selected]
  local fn = item and actions[item.id]
  if fn then
    fn(item)
  end
end

local function item_at(line)
  for index, item in ipairs(state.items or {}) do
    if item.line == line then
      return index
    end
  end
end

--- Keep the cursor on a row: j/k, gg/G and clicks all land on the nearest row in the travel direction.
local function snap_to_row()
  local items = state.items
  if not items or #items == 0 then
    return
  end
  local line = vim.api.nvim_win_get_cursor(state.win)[1]
  local index = item_at(line)
  if not index then
    local down = line > (state.cursor_line or line)
    if down then
      for i, item in ipairs(items) do
        if item.line > line then
          index = i
          break
        end
      end
      index = index or #items
    else
      for i = #items, 1, -1 do
        if items[i].line < line then
          index = i
          break
        end
      end
      index = index or 1
    end
  end
  if index ~= state.selected or not item_at(line) then
    state.selected = index
    refresh()
  end
  state.cursor_line = items[state.selected].line
end

local function buffer_maps(buf)
  local opts = { buffer = buf, silent = true }
  vim.keymap.set("n", "<CR>", activate, opts)
  vim.keymap.set("n", "<2-LeftMouse>", activate, opts)
end

local function window_opts(win)
  local function set(name, value)
    vim.api.nvim_set_option_value(name, value, { scope = "local", win = win })
  end
  set("number", false)
  set("relativenumber", false)
  set("signcolumn", "no")
  set("cursorline", false)
  set("cursorcolumn", false)
  set("spell", false)
  set("list", false)
  set("wrap", false)
  set("colorcolumn", "")
  set("foldenable", false)
  set("statuscolumn", "")
  set("winbar", "")
  set("scrolloff", 0)
  set("sidescrolloff", 0)
  pcall(set, "fillchars", "eob: ")
end

local function detect_motion()
  if vim.g.nvim_home_animate == false then
    state.reduce_motion = true
    return
  end
  if vim.fn.has "macunix" ~= 1 then
    return
  end
  vim.system({ "defaults", "read", "com.apple.universalaccess", "reduceMotion" }, { text = true }, function(obj)
    vim.schedule(function()
      if not state.open then
        return
      end
      if obj.code == 0 and vim.trim(obj.stdout or "") == "1" then
        state.reduce_motion = true
        stop_timer()
      end
    end)
  end)
end

local function refresh_branch()
  local cwd = vim.fn.getcwd()
  vim.system({ "git", "rev-parse", "--abbrev-ref", "HEAD" }, { text = true, cwd = cwd }, function(obj)
    vim.schedule(function()
      if not state.open or vim.fn.getcwd() ~= cwd then
        return
      end
      local branch = obj.code == 0 and vim.trim(obj.stdout or "") or nil
      if branch == "" or branch == "HEAD" then
        branch = nil
      end
      if branch ~= state.branch then
        state.branch = branch
        render_full()
      end
    end)
  end)
end

local function refresh_startup()
  vim.defer_fn(function()
    if not state.open or state.startup_ms then
      return
    end
    local ok, stats = pcall(function()
      return require("lazy.stats").stats()
    end)
    if ok and stats and stats.startuptime and stats.startuptime > 0 then
      state.startup_ms = math.floor(stats.startuptime + 0.5)
      render_full()
    end
  end, 80)
end

local function attach(win)
  local buf = vim.api.nvim_win_get_buf(win)
  state.open = true
  state.win = win
  state.buf = buf
  state.selected = 1
  state.cursor_line = nil
  state.tick = 0
  state.branch = nil
  state.recents = {}

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile = false
  vim.bo[buf].undolevels = -1
  vim.bo[buf].filetype = "nvim_home"
  vim.bo[buf].modifiable = false
  pcall(function()
    vim.b[buf].completion = false
  end)

  window_opts(win)
  M.apply_highlights()
  buffer_maps(buf)

  local group = vim.api.nvim_create_augroup("nvim_home_buf", { clear = true })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    callback = function()
      close()
    end,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    buffer = buf,
    callback = function()
      if state.placing or not state.open then
        return
      end
      snap_to_row()
    end,
  })
  vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
    group = group,
    callback = function()
      if state.open then
        render_full()
        sync_chrome()
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      if state.open then
        sync_chrome()
      end
    end,
  })

  sync_chrome()
  render_full()
  state.laid_width = vim.api.nvim_win_get_width(win)
  state.laid_height = vim.api.nvim_win_get_height(win)
  detect_motion()
  refresh_branch()
  refresh_startup()
  start_timer()
end

local function should_startup()
  if vim.g.vscode then
    return false
  end
  local uis = vim.api.nvim_list_uis()
  if #uis == 0 then
    return false
  end
  if uis[1].stdout_tty and not uis[1].stdin_tty then
    return false
  end
  if vim.fn.argc(-1) > 0 then
    return false
  end
  if vim.api.nvim_buf_get_name(0) ~= "" or vim.bo.modified then
    return false
  end
  local wins = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      wins[#wins + 1] = win
    end
  end
  if #wins ~= 1 or vim.api.nvim_win_get_buf(wins[1]) ~= 1 then
    return false
  end
  if vim.api.nvim_buf_line_count(1) > 1 then
    return false
  end
  local first = vim.api.nvim_buf_get_lines(1, 0, 1, false)[1] or ""
  return first == ""
end

function M.open(opts)
  opts = opts or {}
  if opts.startup then
    if state.open or not should_startup() then
      return
    end
    attach(vim.api.nvim_get_current_win())
    return
  end

  if state.open and vim.api.nvim_get_current_buf() == state.buf then
    state.selected = 1
    render_full()
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local named = vim.api.nvim_buf_get_name(buf) ~= ""
  local special = vim.bo[buf].buftype ~= ""
  if named or special or vim.bo[buf].modified then
    vim.cmd "enew"
  end
  attach(vim.api.nvim_get_current_win())
end

function M.setup()
  if vim.g.vscode then
    return
  end
  vim.api.nvim_create_user_command("Home", function()
    M.open()
  end, { desc = "Open the start screen" })

  local group = vim.api.nvim_create_augroup("nvim_home", { clear = true })
  vim.api.nvim_create_autocmd("UIEnter", {
    group = group,
    once = true,
    callback = function()
      M.open { startup = true }
    end,
  })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      if glyphs then
        glyphs = nil
      end
      M.apply_highlights()
      if state.open then
        render_full()
      end
    end,
  })
  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = { "laststatus", "showtabline" },
    callback = function()
      if state.forcing or not state.open or not state.solo then
        return
      end
      if vim.o.laststatus ~= 0 then
        state.want_laststatus = vim.o.laststatus
      end
      if vim.o.showtabline ~= 0 then
        state.want_showtabline = vim.o.showtabline
      end
      if vim.o.laststatus ~= 0 or vim.o.showtabline ~= 0 then
        state.forcing = true
        vim.o.laststatus = 0
        vim.o.showtabline = 0
        state.forcing = false
      end
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "VeryLazy",
    callback = function()
      if state.open then
        sync_chrome()
      end
    end,
  })
  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      if not state.open then
        return
      end
      state.branch = nil
      refresh_branch()
      render_full()
    end,
  })
end

return M

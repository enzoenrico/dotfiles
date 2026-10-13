--- Fastfetch splash for the home screen.
--- Same clip and chafa settings as anifetch: ascii symbols, foreground only, 10 fps.

local M = {}

local FPS = 10
local CELL_ASPECT = 4.75

local mem = {}
local pending = {}
local colors = {}
local resolved = {
  video = nil,
  tools = nil,
  failed = false,
  notified = false,
}

local function color_name(r, g, b)
  r = math.max(0, math.min(255, r))
  g = math.max(0, math.min(255, g))
  b = math.max(0, math.min(255, b))
  local hex = string.format("%02x%02x%02x", r, g, b)
  local name = "HomeC_" .. hex
  colors[name] = "#" .. hex
  return name
end

local function apply_sgr(params, fg)
  local nums = {}
  for part in (params .. ";"):gmatch("(.-);") do
    nums[#nums + 1] = tonumber(part) or 0
  end
  local i = 1
  while i <= #nums do
    local n = nums[i]
    if n == 0 or n == 39 then
      fg = nil
      i = i + 1
    elseif n == 38 and nums[i + 1] == 2 and nums[i + 2] and nums[i + 3] and nums[i + 4] then
      fg = color_name(nums[i + 2], nums[i + 3], nums[i + 4])
      i = i + 5
    elseif n == 38 and nums[i + 1] == 5 then
      i = i + 3
    else
      i = i + 1
    end
  end
  return fg
end

local function utf8_at(text, i)
  local b = text:byte(i)
  local len = 1
  if b >= 240 then
    len = 4
  elseif b >= 224 then
    len = 3
  elseif b >= 192 then
    len = 2
  end
  if i + len - 1 > #text then
    len = 1
  end
  return text:sub(i, i + len - 1), len
end

--- Turn one chafa frame into span lines clipped to cols.
function M.parse(text, cols)
  local lines = {}
  local spans = {}
  local run, run_hl = "", nil
  local col = 0
  local fg = nil

  local function flush()
    if run ~= "" then
      spans[#spans + 1] = run_hl and { text = run, hl = run_hl } or { text = run }
      run = ""
      run_hl = nil
    end
  end

  local function finish_line()
    flush()
    lines[#lines + 1] = spans
    spans = {}
    col = 0
  end

  local i = 1
  local n = #text
  while i <= n do
    local b = text:byte(i)
    if b == 27 and text:byte(i + 1) == 91 then
      local j = i + 2
      local params
      local cmd
      while j <= n do
        local cj = text:byte(j)
        if cj >= 64 and cj <= 126 then
          params = text:sub(i + 2, j - 1)
          cmd = string.char(cj)
          break
        end
        j = j + 1
      end
      if not cmd then
        break
      end
      if cmd == "m" then
        local next_fg = apply_sgr(params or "", fg)
        if next_fg ~= fg then
          flush()
          fg = next_fg
          run_hl = fg
        end
      end
      i = j + 1
    elseif b == 10 then
      finish_line()
      i = i + 1
    elseif b == 13 then
      i = i + 1
    else
      local ch, len = utf8_at(text, i)
      local cw = vim.fn.strwidth(ch)
      if cols and col + cw > cols then
        ch = ""
        cw = 0
      end
      if ch ~= "" then
        if fg ~= run_hl then
          flush()
          run_hl = fg
        end
        run = run .. ch
        col = col + cw
      end
      i = i + len
    end
  end
  if run ~= "" or #spans > 0 then
    finish_line()
  end

  while #lines > 0 do
    local last = lines[#lines]
    local blank = true
    for _, span in ipairs(last) do
      if (span.text or ""):find("%S") then
        blank = false
        break
      end
    end
    if not blank then
      break
    end
    table.remove(lines)
  end
  return lines
end

local function line_width(spans)
  local width = 0
  for _, span in ipairs(spans) do
    width = width + vim.fn.strwidth(span.text or "")
  end
  return width
end

local function normalize(lines, rows, cols)
  local max_w = 0
  for _, line in ipairs(lines) do
    max_w = math.max(max_w, line_width(line))
  end
  if cols and max_w > cols then
    max_w = cols
  end
  for _, line in ipairs(lines) do
    local gap = max_w - line_width(line)
    if gap > 0 then
      line[#line + 1] = { text = string.rep(" ", gap) }
    end
  end

  if rows and #lines > rows then
    local drop = #lines - rows
    local top = math.floor(drop / 2)
    local out = {}
    for i = 1, rows do
      out[i] = lines[top + i] or {}
    end
    lines = out
  elseif rows and #lines < rows then
    local pad = rows - #lines
    local top = math.floor(pad / 2)
    local out = {}
    for _ = 1, top do
      out[#out + 1] = { { text = string.rep(" ", math.max(max_w, 1)) } }
    end
    for _, line in ipairs(lines) do
      out[#out + 1] = line
    end
    while #out < rows do
      out[#out + 1] = { { text = string.rep(" ", math.max(max_w, 1)) } }
    end
    lines = out
  end
  return lines
end

function M.apply_highlights()
  for name, hex in pairs(colors) do
    vim.api.nvim_set_hl(0, name, { fg = hex })
  end
end

function M.absent()
  return resolved.failed or resolved.video == false or resolved.tools == false
end

local function video_path()
  if resolved.video ~= nil then
    return resolved.video
  end
  local function exists(path)
    return path and path ~= "" and vim.uv.fs_stat(path) ~= nil
  end
  local env = vim.env.ANIFETCH_VIDEO
  if exists(env) then
    resolved.video = env
    return env
  end
  local home = vim.env.HOME or ""
  local bundled = home .. "/Library/Application Support/anifetch/assets/example.mp4"
  if exists(bundled) then
    resolved.video = bundled
    return bundled
  end
  local probe = vim.fn.system {
    "python3",
    "-c",
    "import anifetch, pathlib; print(pathlib.Path(anifetch.__file__).parent / 'assets' / 'example.mp4')",
  }
  if vim.v.shell_error == 0 then
    local path = vim.trim(probe)
    if exists(path) then
      resolved.video = path
      return path
    end
  end
  resolved.video = false
  return false
end

local function tools_ok()
  if resolved.tools ~= nil then
    return resolved.tools
  end
  resolved.tools = vim.fn.executable("ffmpeg") == 1 and vim.fn.executable("chafa") == 1
  return resolved.tools
end

local function cache_path(video, cols, rows)
  local stat = vim.uv.fs_stat(video)
  if not stat then
    return nil
  end
  local mtime = stat.mtime and stat.mtime.sec or 0
  local stamp = table.concat({ video, mtime, stat.size, cols, rows, "ascii-fg-fps10-q6" }, "|")
  local hash = vim.fn.sha256(stamp):sub(1, 20)
  local dir = vim.fn.stdpath("cache") .. "/nvim-home-anim"
  return dir .. "/" .. hash .. ".json", dir
end

local function spans_to_json(lines)
  local frames = {}
  for i, line in ipairs(lines) do
    local row = {}
    for _, span in ipairs(line) do
      row[#row + 1] = { span.text or "", span.hl and span.hl:gsub("^HomeC_", "") or "" }
    end
    frames[i] = row
  end
  return frames
end

local function spans_from_json(lines)
  local out = {}
  for i, line in ipairs(lines) do
    local row = {}
    for _, pair in ipairs(line) do
      local text = pair[1] or ""
      local hex = pair[2]
      if hex and hex ~= vim.NIL and hex ~= "" then
        local name = "HomeC_" .. hex
        colors[name] = "#" .. hex
        row[#row + 1] = { text = text, hl = name }
      elseif text ~= "" then
        row[#row + 1] = { text = text }
      end
    end
    out[i] = row
  end
  return out
end

local function store(key, frames)
  mem[key] = frames
end

local load_cache

local function try_load(cols, rows)
  local key = cols .. "x" .. rows
  if mem[key] or pending[key] or resolved.failed then
    return
  end
  local video = video_path()
  if video == false or not tools_ok() then
    return
  end
  local file = cache_path(video, cols, rows)
  if file and vim.uv.fs_stat(file) and load_cache(key, file, rows, cols) then
    M.apply_highlights()
  end
end

function M.frame(tick, cols, rows)
  local frames = mem[cols .. "x" .. rows]
  if not frames or #frames == 0 then
    return nil
  end
  local index = (tick % #frames) + 1
  return frames[index]
end

--- Load a finished cache for the size the layout settled on. True when frames just became available.
function M.warm(cols, rows)
  local key = cols .. "x" .. rows
  if mem[key] or pending[key] then
    return false
  end
  try_load(cols, rows)
  return mem[key] ~= nil
end

local function fail(msg)
  resolved.failed = true
  if resolved.notified then
    return
  end
  resolved.notified = true
  vim.schedule(function()
    vim.notify(msg, vim.log.levels.WARN, { title = "Home" })
  end)
end

function load_cache(key, file, rows, cols)
  local ok, decoded = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))
  end)
  if not ok or type(decoded) ~= "table" or type(decoded[1]) ~= "table" then
    return false
  end
  local frames = {}
  for i, frame in ipairs(decoded) do
    frames[i] = normalize(spans_from_json(frame), rows, cols)
  end
  if #frames == 0 then
    return false
  end
  store(key, frames)
  return true
end

local function save_cache(file, dir, frames)
  vim.fn.mkdir(dir, "p")
  local payload = {}
  for i, frame in ipairs(frames) do
    payload[i] = spans_to_json(frame)
  end
  local ok, encoded = pcall(vim.json.encode, payload)
  if not ok then
    return
  end
  local tmp = file .. ".tmp"
  vim.fn.writefile({ encoded }, tmp)
  vim.fn.rename(tmp, file)
end

local function run_pool(items, limit, on_one, on_done)
  local next_i = 1
  local running = 0
  local function pump()
    if next_i > #items and running == 0 then
      on_done()
      return
    end
    while running < limit and next_i <= #items do
      local index = next_i
      next_i = next_i + 1
      running = running + 1
      vim.system(items[index], { stdin = false, text = true }, function(obj)
        vim.schedule(function()
          running = running - 1
          on_one(index, obj)
          pump()
        end)
      end)
    end
  end
  pump()
end

local function build(video, cols, rows, key, file, dir, on_done)
  local work = dir .. "/work-" .. cols .. "x" .. rows
  vim.fn.delete(work, "rf")
  vim.fn.mkdir(work, "p")
  vim.system({
    "ffmpeg",
    "-y",
    "-hide_banner",
    "-loglevel",
    "error",
    "-i",
    video,
    "-vf",
    "fps=" .. FPS .. ",format=rgba",
    "-q:v",
    "6",
    work .. "/%05d.jpg",
  }, { stdin = false }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        vim.fn.delete(work, "rf")
        on_done(false)
        return
      end
      local files = vim.fn.glob(work .. "/*.jpg", false, true)
      table.sort(files)
      if #files == 0 then
        vim.fn.delete(work, "rf")
        on_done(false)
        return
      end
      local cmds = {}
      for i, path in ipairs(files) do
        cmds[i] = {
          "chafa",
          "--symbols",
          "ascii",
          "--fg-only",
          "--format",
          "symbols",
          "--size=" .. cols .. "x" .. rows,
          path,
        }
      end
      local parsed = {}
      run_pool(cmds, 4, function(index, result)
        if result.code == 0 and result.stdout and result.stdout ~= "" then
          parsed[index] = normalize(M.parse(result.stdout, cols), rows, cols)
        end
      end, function()
        local frames = {}
        for i = 1, #files do
          if parsed[i] then
            frames[#frames + 1] = parsed[i]
          end
        end
        vim.fn.delete(work, "rf")
        if #frames < math.max(1, math.floor(#files / 2)) then
          on_done(false)
          return
        end
        store(key, frames)
        save_cache(file, dir, frames)
        on_done(true)
      end)
    end)
  end)
end

function M.ensure(cols, rows, on_ready)
  if resolved.failed or not cols or not rows then
    return
  end
  local video = video_path()
  if video == false or not tools_ok() then
    return
  end
  local key = cols .. "x" .. rows
  if mem[key] or pending[key] then
    return
  end
  local file, dir = cache_path(video, cols, rows)
  if not file then
    return
  end
  pending[key] = true
  local function finish(ok)
    pending[key] = nil
    if ok then
      M.apply_highlights()
    else
      fail("Couldn't render the fastfetch animation for the home screen.")
    end
    if on_ready then
      vim.schedule(on_ready)
    end
  end
  if vim.uv.fs_stat(file) then
    vim.schedule(function()
      if load_cache(key, file, rows, cols) then
        finish(true)
      else
        build(video, cols, rows, key, file, dir, finish)
      end
    end)
    return
  end
  build(video, cols, rows, key, file, dir, finish)
end

--- Columns for a hero of `rows`, matching the video's cell aspect.
function M.cols_for(rows, content_w)
  local cols = math.floor(rows * CELL_ASPECT + 0.5)
  if cols % 2 == 1 then
    cols = cols - 1
  end
  if content_w and cols > content_w then
    cols = content_w
    if cols % 2 == 1 then
      cols = cols - 1
    end
  end
  if cols < 28 or rows < 6 then
    return nil
  end
  return cols
end

return M

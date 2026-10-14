--- Drive the shipped Ctrl+Enter and Enter maps in the Snacks sidebar and files picker.
--- nvim --headless loads the user config first; this file only invokes those maps.
--- Set CTRL_ENTER_OUT to the directory that should receive the capture files.
vim.o.lines = 48
vim.o.columns = 300
vim.o.switchbuf = "uselast"
vim.o.hidden = true
vim.o.swapfile = false
vim.o.confirm = false
vim.o.more = false
vim.o.winminwidth = 1
vim.o.winminheight = 1
vim.o.equalalways = false

local out_dir = vim.env.CTRL_ENTER_OUT
if not out_dir or out_dir == "" then
  error("CTRL_ENTER_OUT is required")
end
vim.fn.mkdir(out_dir, "p")

local run = vim.env.CTRL_ENTER_RUN or "1"
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local other = root .. "/other.lua"
local target = root .. "/target.lua"
vim.fn.mkdir(root .. "/subdir", "p")
vim.fn.writefile({ "return 2" }, other)
vim.fn.writefile({ "return 1" }, target)

local failed = false
local sections = {
  sidebar = { "run=" .. run, "switchbuf=" .. vim.o.switchbuf },
  enter = { "run=" .. run, "switchbuf=" .. vim.o.switchbuf },
  picker = { "run=" .. run, "switchbuf=" .. vim.o.switchbuf },
}

local function note(section, line)
  sections[section][#sections[section] + 1] = line
end

local function fail(section, line)
  failed = true
  note(section, "FAIL " .. line)
end

local function pass(section, line)
  note(section, "PASS " .. line)
end

local function base(buf)
  return vim.fn.fnamemodify(vim.fn.resolve(vim.api.nvim_buf_get_name(buf)), ":t")
end

local function editor_wins()
  local ids = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative == "" and vim.bo[buf].buftype == "" and not vim.w[win].snacks_layout then
      ids[#ids + 1] = win
    end
  end
  return ids
end

local function sidebar_open()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_picker_list" then
      return true
    end
  end
  return false
end

local function beside(anchor, win)
  if not (vim.api.nvim_win_is_valid(anchor) and vim.api.nvim_win_is_valid(win)) then
    return false
  end
  local a = vim.api.nvim_win_get_position(anchor)
  local b = vim.api.nvim_win_get_position(win)
  if a[1] ~= b[1] or a[2] == b[2] then
    return false
  end
  if vim.o.splitright then
    return b[2] > a[2]
  end
  return true
end

local function place(picker, name)
  local seen = {}
  for _ = 1, 40 do
    for item, idx in picker:iter() do
      if item.file and not item.dir and item.file:find(name, 1, true) then
        picker.list:view(idx, nil, false)
        local current = picker:current()
        if current and not current.dir and current.file and current.file:find(name, 1, true) then
          return current
        end
      end
      seen[#seen + 1] = (item.file or "?") .. (item.dir and "/dir" or "")
    end
    vim.wait(50, function()
      return false
    end)
  end
  error("cursor did not land on " .. name .. " items=" .. table.concat(seen, ","))
end

local function win_of(picker, which)
  local win = which == "input" and picker.input.win.win or picker.list.win.win
  if not (win and vim.api.nvim_win_is_valid(win)) then
    error(which .. " window missing")
  end
  return win
end

local function map_call(picker, which, lhs, mode)
  vim.api.nvim_set_current_win(win_of(picker, which))
  local map = vim.fn.maparg(lhs, mode, false, true)
  if map.buffer ~= 1 or type(map.callback) ~= "function" then
    error(which .. " " .. mode .. " " .. lhs .. " map missing desc=" .. tostring(map.desc))
  end
  if map.desc ~= "Open in a new split" and lhs ~= "<CR>" then
    error(which .. " " .. mode .. " " .. lhs .. " desc=" .. tostring(map.desc))
  end
  map.callback()
end

local chords = {
  { which = "list", lhs = "<M-CR>", mode = "n" },
  { which = "list", lhs = "<M-CR>", mode = "i" },
  { which = "list", lhs = "<M-kEnter>", mode = "n" },
  { which = "list", lhs = "<M-kEnter>", mode = "i" },
  { which = "input", lhs = "<M-CR>", mode = "n" },
  { which = "input", lhs = "<M-CR>", mode = "i" },
  { which = "input", lhs = "<M-kEnter>", mode = "n" },
  { which = "input", lhs = "<M-kEnter>", mode = "i" },
}

local function wait_picker(picker)
  return vim.wait(3000, function()
    local list = picker.list and picker.list.win and picker.list.win.win
    local input = picker.input and picker.input.win and picker.input.win.win
    return list and vim.api.nvim_win_is_valid(list) and input and vim.api.nvim_win_is_valid(input) and picker:count() > 0
  end)
end

local function check_split(section, picker, editor, editor_buf, label)
  local before = editor_wins()
  local ok, err = pcall(place, picker, "target.lua")
  if not ok then
    fail(section, label .. " " .. err)
    return
  end
  local which, lhs, mode = label:match("^(%S+) (%S+) (%S+)$")
  ok, err = pcall(map_call, picker, which, lhs, mode)
  if not ok then
    fail(section, label .. " " .. err)
    return
  end
  vim.wait(1000, function()
    return #editor_wins() > #before
  end)
  local after = editor_wins()
  local added
  local before_set = {}
  for _, win in ipairs(before) do
    before_set[win] = true
  end
  for _, win in ipairs(after) do
    if not before_set[win] then
      added = win
      break
    end
  end
  local same = vim.api.nvim_win_is_valid(editor) and vim.api.nvim_win_get_buf(editor) == editor_buf
  local cur = added and base(vim.api.nvim_win_get_buf(added)) or base(vim.api.nvim_get_current_buf())
  local side = added and beside(editor, added) or false
  local sidebar = section == "picker" or sidebar_open()
  local good = #after == #before + 1 and same and cur == "target.lua" and side and sidebar
  local line = string.format(
    "%s editors %d -> %d same=%s added=%s beside=%s sidebar=%s",
    label,
    #before,
    #after,
    tostring(same),
    cur,
    tostring(side),
    tostring(sidebar_open())
  )
  if good then
    pass(section, line)
  else
    fail(section, line)
  end
end

local function section_failed(lines)
  for _, line in ipairs(lines) do
    if line:sub(1, 5) == "FAIL " then
      return true
    end
  end
  return false
end

local function write_captures()
  local files = {
    sidebar = "sidebar-ctrl-enter.txt",
    picker = "picker-ctrl-enter.txt",
    enter = "sidebar-enter.txt",
  }
  for key, name in pairs(files) do
    local lines = sections[key]
    lines[#lines + 1] = "RESULT " .. (section_failed(lines) and "FAIL" or "PASS")
    lines[#lines + 1] = ""
    vim.fn.writefile(lines, out_dir .. "/" .. name, "a")
  end
end

local function main()
  vim.cmd("edit " .. vim.fn.fnameescape(other))
  local editor = vim.api.nvim_get_current_win()
  local editor_buf = vim.api.nvim_win_get_buf(editor)

  local explorer = Snacks.explorer.open({ cwd = root, focus = "list" })
  if not wait_picker(explorer) then
    error("sidebar did not open")
  end

  for _, chord in ipairs(chords) do
    check_split("sidebar", explorer, editor, editor_buf, chord.which .. " " .. chord.lhs .. " " .. chord.mode)
    vim.wait(50, function()
      return false
    end)
  end

  local dir_before = #editor_wins()
  local dir_ok, dir_err = pcall(function()
    local item
    for _ = 1, 40 do
      for candidate, idx in explorer:iter() do
        if candidate.dir and candidate.file and candidate.file:find("subdir", 1, true) then
          explorer.list:view(idx, nil, false)
          item = explorer:current()
          break
        end
      end
      if item and item.dir then
        break
      end
      vim.wait(50, function()
        return false
      end)
    end
    if not (item and item.dir and item.file and item.file:find("subdir", 1, true)) then
      error("directory row missing")
    end
    map_call(explorer, "list", "<M-CR>", "n")
  end)
  vim.wait(100, function()
    return false
  end)
  local dir_after = #editor_wins()
  local dir_same = vim.api.nvim_win_is_valid(editor) and vim.api.nvim_win_get_buf(editor) == editor_buf
  if dir_ok and dir_after == dir_before and dir_same then
    pass("sidebar", string.format("dir list <M-CR> n editors %d -> %d same=true", dir_before, dir_after))
  else
    fail("sidebar", string.format("dir list <M-CR> n editors %d -> %d same=%s err=%s", dir_before, dir_after, tostring(dir_same), tostring(dir_err)))
  end

  local enter_before = #editor_wins()
  local ok, err = pcall(function()
    place(explorer, "target.lua")
    map_call(explorer, "list", "<CR>", "n")
  end)
  vim.wait(200, function()
    return false
  end)
  local enter_after = #editor_wins()
  local enter_name = base(vim.api.nvim_win_get_buf(editor))
  if not ok then
    fail("enter", "list <CR> n " .. err)
  elseif enter_after == enter_before and enter_name == "target.lua" and sidebar_open() then
    pass("enter", string.format("list <CR> n editors %d -> %d editor=%s sidebar=true", enter_before, enter_after, enter_name))
  else
    fail("enter", string.format("list <CR> n editors %d -> %d editor=%s sidebar=%s err=%s", enter_before, enter_after, enter_name, tostring(sidebar_open()), tostring(err)))
  end

  vim.api.nvim_set_current_win(editor)
  vim.cmd("buffer " .. editor_buf)
  editor_buf = vim.api.nvim_win_get_buf(editor)

  for _, chord in ipairs(chords) do
    local files = Snacks.picker.files({ cwd = root })
    if not wait_picker(files) then
      fail("picker", chord.which .. " " .. chord.lhs .. " " .. chord.mode .. " picker did not open")
    else
      check_split("picker", files, editor, editor_buf, chord.which .. " " .. chord.lhs .. " " .. chord.mode)
    end
    vim.wait(50, function()
      return false
    end)
  end
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
  failed = true
  note("sidebar", "FAIL crash " .. tostring(err))
  note("enter", "FAIL crash " .. tostring(err))
  note("picker", "FAIL crash " .. tostring(err))
end

write_captures()
vim.cmd(failed and "cquit 1" or "qa!")

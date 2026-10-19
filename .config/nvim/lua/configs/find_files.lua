--- Files picker: keep the normal hidden search, and also list gitignored .env files.
--- `hidden` shows other dotfiles. fd/rg still skip paths matched by .gitignore,
--- which is where .env and .env.* usually live.
local M = {}

local uv = vim.uv or vim.loop

--- Directories that are large and never hold a project env file we want.
local skip_dirs = {
  ".git",
  "node_modules",
  ".next",
  "dist",
  "build",
  "DerivedData",
  ".xcodeproj",
  ".xcworkspace",
  "Pods",
  ".swiftpm",
  "vendor",
  ".cache",
  "target",
  ".venv",
  "__pycache__",
}

local function finder_cwd(opts)
  if opts.rtp or (opts.dirs and #opts.dirs > 0) then
    return nil
  end
  return vim.fs.normalize(opts.cwd or uv.cwd() or ".")
end

local function skip_list(opts)
  local names = {}
  local seen = {}
  local function add(name)
    if name and name ~= "" and not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  for _, name in ipairs(skip_dirs) do
    add(name)
  end
  for _, name in ipairs(opts.exclude or {}) do
    add(name)
  end
  return names
end

---@param opts snacks.picker.files.Config
---@return string? cmd, string[]? args
local function env_cmd(opts)
  local skip = skip_list(opts)
  if vim.fn.executable "fd" == 1 or vim.fn.executable "fdfind" == 1 then
    local args = {
      "--hidden",
      "--no-ignore",
      "--type",
      "f",
      "--type",
      "l",
      "--color",
      "never",
    }
    if opts.follow then
      args[#args + 1] = "-L"
    end
    for _, name in ipairs(skip) do
      args[#args + 1] = "--exclude"
      args[#args + 1] = name
    end
    -- Basename only: .env and .env.*, not .envrc or foo.env.
    args[#args + 1] = "--"
    args[#args + 1] = [[^\.env($|\.)]]
    if opts.dirs and #opts.dirs > 0 then
      vim.list_extend(args, opts.dirs)
    end
    local cmd = vim.fn.executable "fd" == 1 and "fd" or "fdfind"
    return cmd, args
  end

  if vim.fn.executable "rg" == 1 then
    local args = {
      "--files",
      "--hidden",
      "--color",
      "never",
      "--no-messages",
      "-g",
      "**/.env",
      "-g",
      "**/.env.*",
    }
    if opts.follow then
      args[#args + 1] = "-L"
    end
    for _, name in ipairs(skip) do
      args[#args + 1] = "-g"
      args[#args + 1] = "!**/" .. name .. "/**"
    end
    if opts.dirs and #opts.dirs > 0 then
      vim.list_extend(args, opts.dirs)
    end
    return "rg", args
  end
end

---@param opts snacks.picker.files.Config
---@param ctx snacks.picker.finder.ctx
function M.finder(opts, ctx)
  local main = require("snacks.picker.source.files").files(opts, ctx)
  -- Hidden off: respect the toggle. Ignored on: the main search already lists .env.
  if opts.hidden == false or opts.ignored then
    return main
  end

  local cmd, args = env_cmd(opts)
  if not cmd then
    return main
  end

  local cwd = finder_cwd(opts)
  local extra = require("snacks.picker.source.proc").proc({
    cmd = cmd,
    args = args,
    cwd = opts.cwd,
    notify = false,
    transform = function(item)
      item.cwd = cwd
      item.file = item.text
    end,
  }, ctx)

  ---@async
  return function(cb)
    local seen = {}
    local function add(item)
      local path = item.file or item.text
      if path and seen[path] then
        return
      end
      if path then
        seen[path] = true
      end
      cb(item)
    end
    if type(main) == "function" then
      main(add)
    elseif type(main) == "table" then
      for _, item in ipairs(main) do
        add(item)
      end
    end
    if type(extra) == "function" then
      extra(add)
    end
  end
end

return M

local M = {}

local subcommands = { "branch", "changes", "close", "files", "refresh", "toggle" }
local scratch_buffers = {}
local last_action

local function git_root()
  local result = vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  return vim.trim(result.stdout or "")
end

local function read_blob(rev, path, cwd)
  local result = vim.system({ "git", "show", ("%s:%s"):format(rev, path) }, { text = true, cwd = cwd }):wait()
  if result.code ~= 0 then
    return nil
  end
  return result.stdout or ""
end

local function relpath(root, abspath)
  if root and vim.startswith(abspath, root .. "/") then
    return abspath:sub(#root + 2)
  end
  return abspath
end

local function branches()
  local result = vim.system({
    "git",
    "for-each-ref",
    "--format=%(refname:short)",
    "refs/heads",
    "refs/remotes",
  }, { text = true }):wait()

  if result.code ~= 0 then
    return {}
  end

  local found = {}
  local seen = {}
  for branch in (result.stdout or ""):gmatch "[^\r\n]+" do
    if not branch:match "/HEAD$" and not seen[branch] then
      seen[branch] = true
      found[#found + 1] = branch
    end
  end
  table.sort(found)
  return found
end

local function complete(arg_lead, command_line, cursor_pos)
  local prefix = command_line:sub(1, cursor_pos)
  local words = {}
  for word in prefix:gmatch "%S+" do
    words[#words + 1] = word
  end
  if prefix:match "%s$" then
    words[#words + 1] = ""
  end

  local candidates = {}
  if #words <= 2 then
    candidates = subcommands
  elseif words[2] == "branch" then
    candidates = branches()
  end

  return vim.tbl_filter(function(candidate)
    return vim.startswith(candidate, arg_lead)
  end, candidates)
end

-- Shows/creates a read-only scratch buffer holding `path` as it existed at
-- `target`, then diffs it inline (via mini.diff overlay) against `base`.
local function open_target_blob(base, target, path, root)
  local target_content = read_blob(target, path, root)
  if target_content == nil then
    vim.notify(("Diffview: %s not found at %s"):format(path, target), vim.log.levels.WARN)
    return
  end

  local name = ("diffview://%s/%s"):format(target, path)
  local bufnr = vim.fn.bufnr(name)
  if bufnr == -1 then
    bufnr = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(bufnr, name)
  end

  local lines = vim.split(target_content, "\n", { plain = true })
  if lines[#lines] == "" then
    lines[#lines] = nil
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].buftype = "nowrite"
  vim.bo[bufnr].filetype = vim.filetype.match { filename = path } or ""
  vim.b[bufnr].minidiff_config = { source = require("mini.diff").gen_source.none() }
  scratch_buffers[bufnr] = true

  vim.cmd.buffer(bufnr)

  local mini_diff = require "mini.diff"
  pcall(mini_diff.enable, bufnr)
  pcall(mini_diff.set_ref_text, bufnr, read_blob(base, path, root) or "")
  local data = mini_diff.get_buf_data(bufnr)
  if data and not data.overlay then
    pcall(mini_diff.toggle_overlay, bufnr)
  end
end

local function open_changes()
  last_action = open_changes
  require("fzf-lua").git_status {
    actions = {
      ["default"] = function(selected, opts)
        require("fzf-lua.actions").file_edit(selected, opts)
        vim.schedule(function()
          local ok, mini_diff = pcall(require, "mini.diff")
          if not ok then
            return
          end
          local bufnr = vim.api.nvim_get_current_buf()
          local data = mini_diff.get_buf_data(bufnr)
          if data and not data.overlay then
            mini_diff.toggle_overlay(bufnr)
          end
        end)
      end,
    },
  }
end

local function open_branch(args)
  if #args < 1 or #args > 2 then
    vim.notify("Usage: :Diffview branch <base> [target]", vim.log.levels.ERROR)
    return
  end

  local root = git_root()
  if not root then
    vim.notify("Diffview: not inside a git repository", vim.log.levels.ERROR)
    return
  end

  local base = args[1]
  local target = args[2] or "HEAD"
  last_action = function()
    open_branch(args)
  end

  require("fzf-lua").git_diff {
    ref = base .. "..." .. target,
    cwd = root,
    actions = {
      ["default"] = function(selected, opts)
        local path_lib = require "fzf-lua.path"
        for _, entry in ipairs(selected) do
          local resolved = path_lib.entry_to_file(entry, opts)
          open_target_blob(base, target, relpath(root, resolved.path), root)
        end
      end,
    },
  }
end

local function close()
  for bufnr in pairs(scratch_buffers) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end
  scratch_buffers = {}
end

local function toggle_overlay()
  local ok, mini_diff = pcall(require, "mini.diff")
  if not ok then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local data = mini_diff.get_buf_data(bufnr)
  if not data then
    vim.notify("Diffview: mini.diff is not attached to this buffer", vim.log.levels.WARN)
    return
  end
  mini_diff.toggle_overlay(bufnr)
end

local function refresh()
  if last_action then
    last_action()
  else
    open_changes()
  end
end

local function dispatch(opts)
  local action = opts.fargs[1]

  if not action or action == "changes" then
    open_changes()
  elseif action == "branch" then
    open_branch(vim.list_slice(opts.fargs, 2))
  elseif action == "close" then
    close()
  elseif action == "files" then
    open_changes()
  elseif action == "refresh" then
    refresh()
  elseif action == "toggle" then
    toggle_overlay()
  else
    vim.notify(
      ("Unknown Diffview command %q. Expected: %s"):format(action, table.concat(subcommands, ", ")),
      vim.log.levels.ERROR
    )
  end
end

function M.setup()
  pcall(vim.api.nvim_del_user_command, "Diffview")
  vim.api.nvim_create_user_command("Diffview", dispatch, {
    nargs = "*",
    complete = complete,
    desc = "Review Git changes via fzf-lua (status/diff pickers) + mini.diff (overlay)",
  })
end

return M

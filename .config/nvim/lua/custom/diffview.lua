local M = {}

local namespace = vim.api.nvim_create_namespace "diffview_inline_changes"
local subcommands = { "branch", "changes", "close", "files", "refresh", "toggle" }
local diffs_only = {}
local hunks_by_buffer = {}
local toggle_diffs

local function run(command, args)
  vim.api.nvim_cmd({ cmd = command, args = args or {} }, {})
end

local function open_changes()
  run("DiffviewOpen")
end

local function open_branch(args)
  if #args < 1 or #args > 2 then
    vim.notify("Usage: :Diffview branch <base> [target]", vim.log.levels.ERROR)
    return
  end

  local target = args[2] or "HEAD"
  run("DiffviewOpen", { args[1] .. "..." .. target })
end

local function dispatch(opts)
  local action = opts.fargs[1]

  if not action or action == "changes" then
    open_changes()
  elseif action == "branch" then
    open_branch(vim.list_slice(opts.fargs, 2))
  elseif action == "close" then
    run("DiffviewClose")
  elseif action == "files" then
    run("DiffviewToggleFiles")
  elseif action == "refresh" then
    run("DiffviewRefresh")
  elseif action == "toggle" then
    toggle_diffs()
  else
    vim.notify(
      ("Unknown Diffview command %q. Expected: %s"):format(action, table.concat(subcommands, ", ")),
      vim.log.levels.ERROR
    )
  end
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

local function old_blob_spec(entry)
  local RevType = require("diffview.vcs.rev").RevType
  local rev = entry.revs.a
  local path = entry.oldpath or entry.path

  if rev.type == RevType.COMMIT then
    return rev.commit .. ":" .. path
  elseif rev.type == RevType.STAGE then
    return (":%d:%s"):format(rev.stage or 0, path)
  end
end

local function current_text(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")
  if #lines > 0 and vim.bo[bufnr].eol then
    text = text .. "\n"
  end
  return text
end

local function changed_ranges(hunks, line_count)
  local ranges = {}

  for _, hunk in ipairs(hunks) do
    local first = math.min(math.max(hunk[3], 1), line_count)
    local last = math.min(math.max(first + math.max(hunk[4], 1) - 1, first), line_count)
    local previous = ranges[#ranges]

    if previous and first <= previous[2] + 1 then
      previous[2] = math.max(previous[2], last)
    else
      ranges[#ranges + 1] = { first, last }
    end
  end

  return ranges
end

local function apply_view_mode(view, bufnr, winid, hunks)
  if not vim.api.nvim_win_is_valid(winid) or vim.api.nvim_win_get_buf(winid) ~= bufnr then
    return
  end

  local enabled = diffs_only[view] == true
  vim.api.nvim_win_call(winid, function()
    vim.wo.foldmethod = "manual"
    vim.wo.foldminlines = 0
    vim.cmd "silent! normal! zE"

    if enabled then
      local next_line = 1
      for _, range in ipairs(changed_ranges(hunks, vim.api.nvim_buf_line_count(bufnr))) do
        if next_line < range[1] then
          vim.cmd(("%d,%dfold"):format(next_line, range[1] - 1))
        end
        next_line = range[2] + 1
      end
      if next_line <= vim.api.nvim_buf_line_count(bufnr) then
        vim.cmd(("%d,%dfold"):format(next_line, vim.api.nvim_buf_line_count(bufnr)))
      end
    end

    vim.wo.foldenable = enabled
    vim.wo.foldlevel = 0
    vim.wo.foldcolumn = "0"
  end)

  vim.b[bufnr].diffview_diffs_only = enabled
end

local function mark_line(bufnr, row, highlight, sign, sign_highlight)
  vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
    line_hl_group = highlight,
    sign_text = sign,
    sign_hl_group = sign_highlight,
    priority = 150,
  })
end

local function mark_deletion(bufnr, row, count)
  local suffix = count == 1 and "line" or "lines"
  vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
    sign_text = "-",
    sign_hl_group = "GitSignsDelete",
    virt_text = { { ("  −%d deleted %s"):format(count, suffix), "DiffDelete" } },
    virt_text_pos = "eol",
    priority = 150,
  })
end

local function apply_inline_changes(bufnr, old_text, view, winid)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

  local hunks = vim.diff(old_text, current_text(bufnr), {
    algorithm = "histogram",
    result_type = "indices",
  })
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  for _, hunk in ipairs(hunks) do
    local old_count = hunk[2]
    local new_start = hunk[3]
    local new_count = hunk[4]
    local is_addition = old_count == 0
    local highlight = is_addition and "DiffAdd" or "DiffChange"
    local sign = is_addition and "+" or "~"
    local sign_highlight = is_addition and "GitSignsAdd" or "GitSignsChange"

    for offset = 0, new_count - 1 do
      local row = math.min(math.max(new_start - 1 + offset, 0), line_count - 1)
      mark_line(bufnr, row, highlight, offset == 0 and sign or nil, sign_highlight)
    end

    local deleted_count = old_count - new_count
    if new_count == 0 then
      deleted_count = old_count
    end
    if deleted_count > 0 then
      local row = math.min(math.max(new_start - 1, 0), line_count - 1)
      mark_deletion(bufnr, row, deleted_count)
    end
  end

  hunks_by_buffer[bufnr] = hunks
  vim.b[bufnr].diffview_inline_hunks = #hunks
  apply_view_mode(view, bufnr, winid, hunks)
end

function M.show_inline_changes(bufnr, winid, context)
  if context.layout_name ~= "diff1_plain" or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  vim.wo[winid].diff = false
  vim.wo[winid].scrollbind = false
  vim.wo[winid].cursorbind = false
  vim.wo[winid].foldenable = false
  vim.wo[winid].foldcolumn = "0"
  vim.wo[winid].signcolumn = "yes"

  local view = require("diffview.lib").get_current_view()
  local entry = view and view.cur_entry
  if not entry or view.cur_layout:get_main_win().file.bufnr ~= bufnr then
    return
  end

  local spec = old_blob_spec(entry)
  if not spec then
    apply_inline_changes(bufnr, "", view, winid)
    return
  end

  vim.system({ "git", "cat-file", "blob", spec }, {
    cwd = view.adapter.ctx.toplevel,
    text = true,
  }, function(result)
    vim.schedule(function()
      local current_view = require("diffview.lib").get_current_view()
      if current_view ~= view or current_view.cur_entry ~= entry then
        return
      end
      apply_inline_changes(bufnr, result.code == 0 and result.stdout or "", view, winid)
    end)
  end)
end

toggle_diffs = function()
  local view = require("diffview.lib").get_current_view()
  if not view or not view.cur_entry then
    vim.notify("No active Diffview", vim.log.levels.WARN)
    return
  end

  diffs_only[view] = not diffs_only[view]
  local main = view.cur_layout:get_main_win()
  local bufnr = main.file.bufnr
  apply_view_mode(view, bufnr, main.id, hunks_by_buffer[bufnr] or {})
  vim.notify(diffs_only[view] and "Diffview: diffs only" or "Diffview: whole file")
end

function M.clear_inline_changes(view)
  if not view.files or not view.files.iter then
    return
  end

  for _, entry in view.files:iter() do
    for _, file in ipairs(entry.layout:files()) do
      local bufnr = file.bufnr
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
        vim.b[bufnr].diffview_inline_hunks = nil
        vim.b[bufnr].diffview_diffs_only = nil
        hunks_by_buffer[bufnr] = nil
      end
    end
  end
  diffs_only[view] = nil
end

function M.setup()
  pcall(vim.api.nvim_del_user_command, "Diffview")
  vim.api.nvim_create_user_command("Diffview", dispatch, {
    nargs = "*",
    complete = complete,
    desc = "Review Git changes in a single-pane Diffview",
  })
end

return M

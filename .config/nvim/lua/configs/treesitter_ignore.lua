--- Disable treesitter for noisy or irrelevant buffers (NvChad starts TS on all filetypes).
local M = {}

local ignored_basenames = {
  ["package.json"] = true,
}

--- Submodule worktrees use a `.git` file; the main repo uses a `.git` directory.
---@param path string
---@return boolean
local function in_git_submodule(path)
  if path == "" then
    return false
  end

  local dir = vim.fs.dirname(path)
  while dir and dir ~= "/" do
    local git = vim.fs.joinpath(dir, ".git")
    local stat = vim.uv.fs_lstat(git)
    if stat then
      return stat.type == "file"
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end

  return false
end

---@param buf? integer
---@return boolean
function M.should_ignore(buf)
  buf = buf or 0
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" then
    return false
  end

  if ignored_basenames[vim.fs.basename(path)] then
    return true
  end

  return in_git_submodule(path)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("treesitter_ignore", { clear = true })

  local function maybe_stop(args)
    if not M.should_ignore(args.buf) then
      return
    end
    -- Run after NvChad's FileType autocmd calls vim.treesitter.start().
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(args.buf) then
        pcall(vim.treesitter.stop, args.buf)
      end
    end)
  end

  vim.api.nvim_create_autocmd({ "FileType", "BufReadPost" }, {
    group = group,
    callback = maybe_stop,
  })
end

return M

local M = {}

-- Shows inline hunk highlights (mini.diff overlay) on the buffer that was
-- just opened, mirroring how the old :Diffview panes highlighted changes.
local function show_diff_in_buffer(bufnr)
  local ok, mini_diff = pcall(require, "mini.diff")
  if not ok then
    return
  end

  if not mini_diff.get_buf_data(bufnr) then
    pcall(mini_diff.enable, bufnr)
  end

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    local data = mini_diff.get_buf_data(bufnr)
    if data and not data.overlay then
      pcall(mini_diff.toggle_overlay, bufnr)
    end
  end)
end

function M.open()
  require("fzf-lua").git_status {
    actions = {
      ["default"] = function(selected, opts)
        require("fzf-lua.actions").file_edit(selected, opts)
        show_diff_in_buffer(vim.api.nvim_get_current_buf())
      end,
    },
  }
end

return M

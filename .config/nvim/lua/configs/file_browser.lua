local M = {}

function M.open()
  local current_file = vim.api.nvim_buf_get_name(0)
  local directory = current_file ~= "" and vim.fn.fnamemodify(current_file, ":p:h") or vim.uv.cwd()

  require("telescope").extensions.file_browser.file_browser {
    path = directory,
    cwd = directory,
    hidden = true,
    grouped = true,
    respect_gitignore = false,
    previewer = false,
    initial_mode = "normal",
    layout_config = { height = 40 },
  }
end

return M

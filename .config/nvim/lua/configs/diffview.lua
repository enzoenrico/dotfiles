local custom_diffview = require "custom.diffview"

require("diffview").setup {
  enhanced_diff_hl = true,
  watch_index = true,
  view = {
    default = {
      layout = "diff2_horizontal",
      disable_diagnostics = true,
      winbar_info = false,
    },
    merge_tool = {
      layout = "diff3_mixed",
      disable_diagnostics = true,
      winbar_info = true,
    },
  },
  file_panel = {
    listing_style = "list",
    win_config = {
      position = "left",
      width = 40,
    },
  },
  default_args = {
    DiffviewOpen = { "--untracked-files=all" },
  },
  hooks = {
    diff_buf_win_enter = custom_diffview.show_inline_changes,
    view_closed = custom_diffview.clear_inline_changes,
  },
}

-- Diffview only exposes its single-pane layout for merge views, but the
-- underlying layout also supports regular and branch comparisons.
require("diffview.config").get_config().view.default.layout = "diff1_plain"

custom_diffview.setup()

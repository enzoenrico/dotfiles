require("diffview").setup {
  enhanced_diff_hl = true,
  watch_index = true,
  view = {
    merge_tool = {
      layout = "diff3_mixed",
      disable_diagnostics = true,
      winbar_info = true,
    },
  },
}

require("fzf-lua").setup {
  winopts = {
    height = 0.85,
    width = 0.90,
    preview = { layout = "vertical", vertical = "down:60%" },
  },
  git = {
    status = {
      prompt = "Git Status ❯ ",
      previewer = "git_diff",
    },
    diff = {
      preview = "git diff {ref} -- {file}",
    },
  },
}

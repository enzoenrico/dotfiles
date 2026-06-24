return {
  {
    "3rd/image.nvim",
    build = false,
    opts = {
      processor = "magick_cli",
    },
  },
  {
    "kawre/leetcode.nvim",
    build = ":TSUpdate html",
    cmd = "Leet",
    event = {
      "BufReadPre leetcode.nvim",
    },
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
      "3rd/image.nvim",
    },
    opts = {
      arg = "leetcode.nvim",
      lang = "swift",
      image_support = true,
      plugins = {
        non_standalone = true,
      },
    },
  },
}

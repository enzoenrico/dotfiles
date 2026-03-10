return {
       {
         "folke/flash.nvim",
         event = "VeryLazy",
    -- cond = not vim.g.vscode,
         opts = {},
         -- stylua: ignore
         keys = {
           -- { "s", mode ={ "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash Jump" },
           { "S", mode = { "n" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
           -- { "r", mode = "o", function() require("flash").remote() end, desc = "Flash Remote" },
           -- { "R", mode = { "n", "x" }, function() require("flash").remote() end, desc = "Flash Remote" },
           -- { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
        },
       },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "vim", "lua", "vimdoc",
        "html", "css", "swift"
      },
    },
  },
  {
  'vscode-neovim/vscode-multi-cursor.nvim',
  event = 'VeryLazy',
  cond = not not vim.g.vscode,
  opts = {},
},
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({})
    end
  },

  -- strudel
--   {
--   "gruvw/strudel.nvim",
--     event= 'VeryLazy',
--   build = 'npm ci',
--     opts = {},
--   config = function()
--     require("strudel").setup()
--   end,
-- }
}

local mac = vim.fn.has "macunix" == 1

return {
  {
    "stevearc/conform.nvim",
    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    cond = function()
      return not vim.g.vscode
    end,
    ---@type snacks.Config
    opts = {
      bigfile = { enabled = true },
      dashboard = { enabled = true },
      explorer = { enabled = true },
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      picker = { enabled = true },
      quickfile = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = { enabled = true },
      words = { enabled = true },
    },
  },

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "vim", "lua", "vimdoc",
        "html", "css", "swift",
      },
    },
  },
  {
    "vscode-neovim/vscode-multi-cursor.nvim",
    event = "VeryLazy",
    cond = not not vim.g.vscode,
    opts = {},
  },
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup {}
    end,
  },

  -- Telescope: Ctrl+j/k for picker nav (Cursor quick-input parity)
  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, opts)
      local actions = require "telescope.actions"
      opts.defaults = vim.tbl_deep_extend("force", opts.defaults or {}, {
        mappings = {
          i = {
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
          },
        },
      })
      return opts
    end,
  },

  -- Sidebar on the right (Cursor workbench.sideBar.location)
  {
    "nvim-tree/nvim-tree.lua",
    opts = function(_, opts)
      opts.view = vim.tbl_deep_extend("force", opts.view or {}, { side = "right" })
      return opts
    end,
  },

  -- Which-key: Space s group label for Swift / Xcodebuild
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      vim.list_extend(opts.spec, {
        { "<leader>s", group = "Swift / Xcodebuild", mode = "n" },
        { "<leader>t", group = "Splits / terminal", mode = "n" },
      })
      return opts
    end,
  },

  -- Smear cursor (~= Cursor Smear Cursor); standalone only
  {
    "sphamba/smear-cursor.nvim",
    cond = function()
      return not vim.g.vscode
    end,
    event = "VeryLazy",
    opts = {
      max_length = 900,
      trailing_stiffness = 0.35,
      trailing_exponent = 2.2,
    },
  },

  {
    "mfussenegger/nvim-dap",
    lazy = true,
    cond = mac,
  },
  {
    "nvim-neotest/nvim-nio",
    lazy = true,
    cond = mac,
  },
  {
    "rcarriga/nvim-dap-ui",
    lazy = true,
    cond = mac,
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
  },

  {
    "MunifTanjim/nui.nvim",
    lazy = true,
    cond = mac,
  },


  -- Sweetpad replacement on macOS (Xcode / SwiftPM). Loads on Swift buffers or :Xcodebuild* commands.
  {
    "wojciech-kulik/xcodebuild.nvim",
    cond = mac,
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "MunifTanjim/nui.nvim",
      "mfussenegger/nvim-dap",
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
    },
    ft = { "swift" },
    cmd = {
      "XcodebuildPicker",
      "XcodebuildSetup",
      "XcodebuildBuild",
      "XcodebuildBuildRun",
      "XcodebuildTest",
    },
    config = function()
      require("dapui").setup()
      require("xcodebuild").setup {}
      require("xcodebuild.integrations.dap").setup()
    end,
  },
  {
    'arnamak/stay-centered.nvim',
    lazy = false,
    opts = {
      skip_filetypes = { 'lua', 'typescript' },
    }
  },
  {
    "mbbill/undotree",
    cmd = "UndotreeToggle",
  },

  { import = "plugins.disabled" },
}

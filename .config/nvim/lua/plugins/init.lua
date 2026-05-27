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
      explorer = {
        enabled = true,
        replace_netrw = false,
      },
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      picker = {
        enabled = true,
        sources = {
          explorer = { hidden = true },
          files = { hidden = true },
        },
      },
      quickfile = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = false },
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
    lazy = false,
    opts = function(_, opts)
      opts = opts or {}
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "vim", "lua", "vimdoc",
        "html", "css", "swift",
      })
      return opts
    end,
    config = function()
      require("nvim-treesitter").setup()
      require("configs.treesitter_nvim012").patch()
      require("configs.treesitter_ignore").setup()
    end,
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
      opts.pickers = opts.pickers or {}
      opts.pickers.find_files = vim.tbl_deep_extend("force", opts.pickers.find_files or {}, {
        hidden = true,
      })
      return opts
    end,
  },

  -- Sidebar on the right (Cursor workbench.sideBar.location)
  {
    "nvim-tree/nvim-tree.lua",
    opts = function(_, opts)
      opts.view = vim.tbl_deep_extend("force", opts.view or {}, { side = "right" })
      opts.filters = vim.tbl_deep_extend("force", opts.filters or {}, {
        dotfiles = false,
      })
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
        { "<leader>tt", desc = "Floating terminal", mode = "n" },
        { "<leader>tb", desc = "Bottom terminal", mode = "n" },
        { "<leader>tV", desc = "Vertical terminal", mode = "n" },
        { "<leader>g", group = "Git", mode = "n" },
        { "<leader>c", group = "Cursor agent", mode = "n" },
      })
      return opts
    end,
  },

  {
    "sindrets/diffview.nvim",
    cond = function()
      return not vim.g.vscode
    end,
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
      "DiffviewFileHistory",
    },
    config = function()
      require "configs.diffview"
    end,
  },

  -- Git UI (libgit2); uses diffview for splits — install libgit2 on the system first.
  {
    "SuperBo/fugit2.nvim",
    build = false,
    cond = function()
      return not vim.g.vscode
    end,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      "nvim-lua/plenary.nvim",
    },
    cmd = {
      "Fugit2",
      "Fugit2Blame",
      "Fugit2Diff",
      "Fugit2Graph",
      "Fugit2Rebase",
    },
    opts = {
      width = 70,
      external_diffview = true,
    },
    keys = {
      { "<leader>gf", "<cmd>Fugit2<cr>", desc = "Fugit2", mode = "n" },
    },
  },

  -- Cursor SDK agent chat (cursor-agent CLI)
  {
    "enzoenrico/cursor.nvim",
    branch = "cursor/avante-ui-overhaul-9164",
    cond = function()
      return not vim.g.vscode
    end,
    cmd = {
      "CursorChat",
      "CursorAsk",
      "CursorStop",
      "CursorStatus",
      "CursorVersion",
      "CursorToggle",
      "CursorFocus",
      "CursorNew",
      "CursorEdit",
      "CursorHistory",
      "CursorModel",
      "CursorZen",
      "CursorApply",
      "CursorApplyAll",
    },
    opts = {
      keymaps = true,
      ui = {
        layout = "right",
      },
    },
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
      local xb = require "configs.xcodebuild"
      xb.setup_dap_ui()
      xb.setup_xcodebuild()
      xb.setup_autocmds()
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
  {
    "wintermute-cell/gitignore.nvim",
      lazy=true,
      config = function()
          require('gitignore')
      end,
  },
  { import = "plugins.disabled" },
}

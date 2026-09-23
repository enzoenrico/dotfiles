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
      notifier = { enabled = false },
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
      statuscolumn = {
        enabled = true,
        left = { "git", "sign", "mark" },
        right = { "fold" },
      },
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
        "vim",
        "lua",
        "vimdoc",
        "html",
        "css",
        "swift",
      })
      return opts
    end,
    config = function(_, opts)
      local ts = require "nvim-treesitter"
      ts.setup(opts)

      -- main-branch API: parsers are installed explicitly (opts alone is not enough).
      local ensure = opts.ensure_installed or {}
      if type(ensure) == "table" and #ensure > 0 and type(ts.install) == "function" then
        ts.install(ensure)
      end

      -- master-only query predicate shim for Neovim 0.12; skip on main.
      if pcall(require, "nvim-treesitter.locals") then
        require("configs.treesitter_nvim012").patch()
      end
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

  -- Native fzf sorter (Lua sorter is the main typing lag in large trees)
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
  },

  -- Telescope: fast find + Ctrl+j/k for picker nav (Cursor quick-input parity)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-telescope/telescope-fzf-native.nvim",
      "nvim-telescope/telescope-file-browser.nvim",
    },
    opts = function(_, opts)
      local actions = require "telescope.actions"
      local fb_actions = require("telescope").extensions.file_browser.actions
      local have_fd = vim.fn.executable "fd" == 1

      opts.defaults = vim.tbl_deep_extend("force", opts.defaults or {}, {
        mappings = {
          i = {
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
          },
        },
        -- Skip huge / generated trees that make fuzzy match crawl
        file_ignore_patterns = {
          "%.git/",
          "node_modules/",
          "%.next/",
          "dist/",
          "build/",
          "DerivedData/",
          "%.xcodeproj/",
          "%.xcworkspace/",
          "Pods/",
          "%.swiftpm/",
          "vendor/",
          "%.cache/",
          "target/",
          "%.venv/",
          "__pycache__/",
        },
        vimgrep_arguments = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
          "--hidden",
          "--glob=!.git/*",
        },
        preview = {
          filesize_limit = 0.5, -- MB; skip huge files in preview
          timeout = 100,
        },
        path_display = { "truncate" },
      })

      opts.pickers = opts.pickers or {}
      -- Prefer fd (Telescope defaults to rg --files even when fd exists).
      -- Keep hidden dotfiles, but never walk .git.
      opts.pickers.find_files = vim.tbl_deep_extend("force", opts.pickers.find_files or {}, {
        hidden = true,
        find_command = have_fd and {
          "fd",
          "--type",
          "f",
          "--color",
          "never",
          "--exclude",
          ".git",
        } or {
          "rg",
          "--files",
          "--color",
          "never",
          "--glob",
          "!.git/*",
        },
      })

      opts.extensions = vim.tbl_deep_extend("force", opts.extensions or {}, {
        fzf = {
          fuzzy = true,
          override_generic_sorter = true,
          override_file_sorter = true,
          case_mode = "smart_case",
        },
        file_browser = {
          theme = "dropdown",
          hijack_netrw = true,
          hidden = { file_browser = true, folder_browser = true },
          grouped = true,
          respect_gitignore = false,
          mappings = {
            n = {
              N = fb_actions.create,
              h = fb_actions.goto_parent_dir,
              ["/"] = function()
                vim.cmd "startinsert"
              end,
              ["<C-u>"] = function(prompt_bufnr)
                for _ = 1, 10 do
                  actions.move_selection_previous(prompt_bufnr)
                end
              end,
              ["<C-d>"] = function(prompt_bufnr)
                for _ = 1, 10 do
                  actions.move_selection_next(prompt_bufnr)
                end
              end,
              ["<PageUp>"] = actions.preview_scrolling_up,
              ["<PageDown>"] = actions.preview_scrolling_down,
            },
          },
        },
      })

      return opts
    end,
    config = function(_, opts)
      require("telescope").setup(opts)
      pcall(require("telescope").load_extension, "fzf")
      pcall(require("telescope").load_extension, "file_browser")
      for _, ext in ipairs(opts.extensions_list or {}) do
        pcall(require("telescope").load_extension, ext)
      end
    end,
  },

  -- Replaced by telescope-file-browser.nvim.
  {
    "nvim-tree/nvim-tree.lua",
    enabled = false,
  },

  -- Which-key: Space s group label for Swift / Xcodebuild
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      vim.list_extend(opts.spec, {
        { "<leader>n", desc = "Dismiss notifications", mode = "n" },
        { "<leader>s", group = "Swift / Xcodebuild", mode = "n" },
        { "<leader>md", desc = "Markdown floating preview", mode = "n" },
        { "<leader>t", group = "Splits / terminal", mode = "n" },
        { "<leader>tt", desc = "Floating terminal", mode = "n" },
        { "<leader>tb", desc = "Bottom terminal", mode = "n" },
        { "<leader>tV", desc = "Vertical terminal", mode = "n" },
        { "<leader>g", group = "Git", mode = "n" },
        { "<leader>c", group = "Code AI", mode = "n" },
        { "<leader>co", desc = "Opencode current file", mode = "n" },
        { "<leader>ca", desc = "Agent current file", mode = "n" },
      })
      return opts
    end,
  },

  -- Inline unified diff viewer (git diff shown directly in the buffer,
  -- with a changed-files tree) — replaces a hand-rolled diffview.nvim hack.
  {
    "axkirillov/unified.nvim",
    cond = function()
      return not vim.g.vscode
    end,
    cmd = "Unified",
    keys = {
      {
        "<leader>gd",
        function()
          require("unified").toggle()
        end,
        desc = "Toggle unified diff",
        mode = "n",
      },
      {
        "<leader>gb",
        function()
          require("unified").pick_commit()
        end,
        desc = "Unified diff: pick base commit",
        mode = "n",
      },
    },
    config = function()
      require "configs.unified"
    end,
  },

  -- Diff, file history, and a 3-way merge. The result pane is the working-tree
  -- file. Fugit2 stays the status, commit, and rebase UI.
  {
    "undont/differ.nvim",
    cond = function()
      return not vim.g.vscode
    end,
    build = "make go-build",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "Differ",
    keys = {
      { "<leader>gv", "<cmd>Differ<cr>", desc = "Differ", mode = "n" },
      { "<leader>gm", "<cmd>Differ mergetool<cr>", desc = "Differ merge", mode = "n" },
      { "<leader>gh", "<cmd>Differ log<cr>", desc = "Differ file history", mode = "n" },
    },
    config = function()
      require "configs.differ"
    end,
  },

  -- Fuzzy git-status picker (stage/unstage from the list) bound to <leader>d;
  -- opening a file from it shows inline hunk highlights via mini.diff.
  {
    "ibhagwan/fzf-lua",
    cond = function()
      return not vim.g.vscode
    end,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "FzfLua",
    keys = {
      {
        "<leader>d",
        function()
          require("custom.git-status").open()
        end,
        desc = "Git status (fzf-lua)",
        mode = "n",
      },
    },
    config = function()
      require "configs.fzf-lua"
    end,
  },

  -- Inline hunk overlay used by the <leader>d git-status picker.
  {
    "echasnovski/mini.diff",
    cond = function()
      return not vim.g.vscode
    end,
    version = false,
    event = "VeryLazy",
    config = function()
      require "configs.mini-diff"
    end,
  },

  -- Git UI (libgit2); install libgit2 on the system first.
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
      external_diffview = false,
    },
    keys = {
      { "<leader>gf", "<cmd>Fugit2<cr>", desc = "Fugit2", mode = "n" },
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
      -- Smoother, less jumpy animation
      time_interval = 7, -- higher framerate (~140fps instead of ~60)
      stiffness = 0.4, -- slower head (default 0.6 jumps most of the way in one frame)
      trailing_stiffness = 0.12, -- tail catches up slowly = long smear
      trailing_exponent = 2, -- taper the body toward the tail
      anticipation = 0.1, -- less initial backward kick
      damping = 0.9, -- fewer overshoot wobbles
      stiffness_insert_mode = 0.4,
      trailing_stiffness_insert_mode = 0.4,
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
    "arnamak/stay-centered.nvim",
    lazy = false,
    opts = {
      skip_filetypes = { "lua", "typescript" },
    },
  },
  {
    "mbbill/undotree",
    cmd = "UndotreeToggle",
  },
  {
    "wintermute-cell/gitignore.nvim",
    lazy = true,
    config = function()
      require "gitignore"
    end,
  },
  { import = "plugins.disabled" },
}

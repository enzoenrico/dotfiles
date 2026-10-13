return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts = opts or {}
      opts.ensure_installed = opts.ensure_installed or {}

      for _, parser in ipairs { "rust", "toml" } do
        if not vim.tbl_contains(opts.ensure_installed, parser) then
          table.insert(opts.ensure_installed, parser)
        end
      end

      return opts
    end,
  },

  -- https://github.com/rust-lang/rust.vim
  -- Filetype, :RustFmt, :RustRun, :RustTest, :RustPlay, cargo compiler.
  {
    "rust-lang/rust.vim",
    ft = "rust",
    init = function()
      -- Format stays on Conform (same keymap as the other languages) and :RustFmt.
      vim.g.rustfmt_autosave = 0
    end,
  },

  {
    "rust-tooling",
    virtual = true,
    ft = "rust",
    dependencies = { "neovim/nvim-lspconfig" },
    config = function()
      local parsers = { "rust", "toml" }
      local ts = require "nvim-treesitter"
      if type(ts.install) == "function" then
        ts.install(parsers)
      else
        local ok, install = pcall(require, "nvim-treesitter.install")
        if ok and install.ensure_installed then
          install.ensure_installed(parsers)
        end
      end

      -- rustup ships a rust-analyzer shim even when the component is missing.
      if vim.fn.executable "rust-analyzer" ~= 1 then
        return
      end
      local version = vim.system({ "rust-analyzer", "--version" }, { text = true }):wait()
      if version.code ~= 0 then
        vim.notify(
          "rust-analyzer failed to start. Install it with: rustup component add rust-analyzer",
          vim.log.levels.WARN
        )
        return
      end
      vim.lsp.enable "rust_analyzer"
    end,
  },
}

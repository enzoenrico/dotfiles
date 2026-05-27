return {
  {
    "nvim-treesitter/nvim-treesitter",
    ft = { "typescript", "typescriptreact" },
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      for _, parser in ipairs { "typescript", "tsx", "javascript", "jsx" } do
        if not vim.tbl_contains(opts.ensure_installed, parser) then
          table.insert(opts.ensure_installed, parser)
        end
      end

      return opts
    end,
  },

  {
    "typescript-tooling",
    virtual = true,
    ft = { "typescript", "typescriptreact" },
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("configs.typescript").setup()
    end,
  },
}

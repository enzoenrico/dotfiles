local web_filetypes = {
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "json",
  "jsonc",
  "html",
  "css",
  "scss",
  "less",
  "astro",
  "svelte",
  "vue",
  "graphql",
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    ft = web_filetypes,
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      for _, parser in ipairs {
        "astro",
        "css",
        "graphql",
        "html",
        "javascript",
        "jsdoc",
        "json",
        "scss",
        "svelte",
        "tsx",
        "typescript",
        "vue",
      } do
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
    ft = web_filetypes,
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("configs.typescript").setup()
    end,
  },

  {
    "brenoprata10/nvim-highlight-colors",
    ft = web_filetypes,
    opts = {
      render = "background",
      enable_hex = true,
      enable_short_hex = true,
      enable_rgb = true,
      enable_hsl = true,
      enable_hsl_without_function = true,
      enable_ansi = true,
      enable_var_usage = true,
      enable_tailwind = true,
    },
  },
}

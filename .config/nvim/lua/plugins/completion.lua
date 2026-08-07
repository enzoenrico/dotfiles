return {
  { import = "nvchad.blink.lazyspec" },

  {
    "saghen/blink.cmp",
    version = "1.*",
    lazy = false,
    opts = function(_, opts)
      opts.keymap = vim.tbl_deep_extend("force", opts.keymap or {}, {
        preset = "none",
        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-k>"] = { "select_prev", "fallback" },
        ["<Down>"] = { "select_next", "fallback" },
        ["<Up>"] = { "select_prev", "fallback" },
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      })

      return opts
    end,
  },
}

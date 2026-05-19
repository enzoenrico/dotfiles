return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      local parsers = {
        "markdown",
        "markdown_inline",
        "mermaid",
        "yaml",
      }

      for _, parser in ipairs(parsers) do
        if not vim.tbl_contains(opts.ensure_installed, parser) then
          table.insert(opts.ensure_installed, parser)
        end
      end

      return opts
    end,
  },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    cmd = { "RenderMarkdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      file_types = { "markdown" },
      render_modes = { "n", "c", "t" },
      anti_conceal = {
        enabled = true,
      },
      heading = {
        width = "full",
      },
      checkbox = {
        enabled = true,
      },
      pipe_table = {
        preset = "round",
      },
      completions = {
        lsp = { enabled = true },
      },
    },
  },

  {
    "iamcco/markdown-preview.nvim",
    ft = { "markdown" },
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    build = "cd app && npx --yes yarn install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_auto_close = 0
      vim.g.mkdp_refresh_slow = 0
      vim.g.mkdp_preview_options = {
        disable_sync_scroll = 0,
        hide_yaml_meta = 0,
        sequence_diagrams = {},
        flowchart_diagrams = {},
        maid = {},
      }
    end,
  },
}

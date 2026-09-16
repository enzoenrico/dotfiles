local standalone = function()
  return not vim.g.vscode
end

local function delete_buffer()
  if Snacks and Snacks.bufdelete then
    Snacks.bufdelete()
  else
    vim.cmd "bdelete"
  end
end

return {
  {
    "rcarriga/nvim-notify",
    cond = standalone,
    opts = {
      timeout = 5000,
      stages = "fade_in_slide_out",
      render = "compact",
      background_colour = "#000000",
    },
  },

  {
    "folke/noice.nvim",
    cond = standalone,
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    opts = {
      routes = {
        {
          filter = {
            event = "notify",
            find = "No information available",
          },
          opts = { skip = true },
        },
      },
      commands = {
        all = {
          view = "split",
          opts = { enter = true, format = "details" },
          filter = {},
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = false,
        lsp_doc_border = true,
      },
    },
  },

  {
    "akinsho/bufferline.nvim",
    cond = standalone,
    event = "VeryLazy",
    dependencies = "nvim-tree/nvim-web-devicons",
    keys = {
      { "<Tab>", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
      { "<S-Tab>", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous buffer" },
      { "<leader>b", "<cmd>enew<cr>", desc = "New buffer" },
      { "<leader>x", delete_buffer, desc = "Close buffer" },
    },
    opts = {
      options = {
        mode = "buffers",
        diagnostics = "nvim_lsp",
        separator_style = "thin",
        show_buffer_close_icons = false,
        show_close_icon = false,
        always_show_bufferline = false,
      },
    },
  },

  {
    "b0o/incline.nvim",
    cond = standalone,
    event = "BufReadPre",
    dependencies = "nvim-tree/nvim-web-devicons",
    opts = {
      window = { margin = { vertical = 0, horizontal = 1 } },
      hide = { cursorline = true },
      render = function(props)
        local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
        if filename == "" then
          filename = "[No Name]"
        end
        if vim.bo[props.buf].modified then
          filename = "[+] " .. filename
        end

        local icon, color = require("nvim-web-devicons").get_icon_color(filename)
        return {
          { icon or "", guifg = color },
          { " " },
          { filename, gui = vim.bo[props.buf].modified and "bold,italic" or "bold" },
        }
      end,
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    cond = standalone,
    event = "VeryLazy",
    dependencies = "nvim-tree/nvim-web-devicons",
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
        component_separators = { left = "│", right = "│" },
        section_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = {
          {
            "filename",
            path = 1,
            symbols = { modified = " [+]", readonly = " 󰌾" },
          },
        },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },

  {
    "folke/zen-mode.nvim",
    cond = standalone,
    cmd = "ZenMode",
    keys = {
      { "<leader>z", "<cmd>ZenMode<cr>", desc = "Zen mode" },
    },
    opts = {
      plugins = {
        gitsigns = true,
        tmux = true,
        kitty = { enabled = false, font = "+2" },
      },
    },
  },
}

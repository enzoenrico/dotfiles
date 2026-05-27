-- Cursor agent sidebar (local dev: ~/code/cursor.nvim/cursor.nvim)
return {
  {
    dir = vim.fn.expand("~/code/cursor.nvim/cursor.nvim"),
    name = "cursor.nvim",
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
      "CursorDebug",
      "CursorLog",
      "CursorLogClear",
    },
    opts = {
      cmd = "cursor-agent",
      keymaps = true,
      trust = true,
      agent = { mode = "interactive" },
      ui = {
        layout = "right",
        width = 30,
        context_height = 3,
        show_hints = true,
      },
    },
  },
}

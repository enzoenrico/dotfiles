local float = function()
  require("configs.toggleterm").toggle_float()
end

local toggle = function(direction, id)
  return function()
    require("configs.toggleterm").toggle(direction, id)
  end
end

return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    cond = function()
      return not vim.g.vscode
    end,
    cmd = {
      "ToggleTerm",
      "ToggleTermToggleAll",
      "ToggleTermSendCurrentLine",
      "ToggleTermSendVisualSelection",
      "ToggleTermSendVisualLines",
    },
    keys = {
      { "<leader>tt", float, mode = { "n", "t" }, desc = "Toggle floating terminal" },
      { "<C-`>", float, mode = { "n", "t" }, desc = "Toggle floating terminal (Cursor panel)" },
      { "<M-J>", float, mode = { "n", "t" }, desc = "Toggle floating terminal (Shift+Alt+j parity)" },
      { "<leader>tb", toggle("horizontal", 2), mode = { "n", "t" }, desc = "Toggle bottom terminal" },
      { "<leader>tV", toggle("vertical", 3), mode = { "n", "t" }, desc = "Toggle vertical terminal" },
    },
    config = function()
      require("configs.toggleterm").setup()
    end,
  },
}

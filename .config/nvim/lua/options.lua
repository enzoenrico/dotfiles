require "nvchad.options"

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 999 -- keep cursor vertically centered (like zz)

vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
  group = vim.api.nvim_create_augroup("gutter-always-on", { clear = true }),
  callback = function()
    if vim.bo.buftype ~= "" then
      return
    end
    vim.wo.number = true
    vim.wo.relativenumber = true
    vim.wo.signcolumn = "yes"
  end,
})

if vim.g.neovide then
  vim.o.guifont = "GeistMono Nerd Font:h16"
end

if not vim.g.vscode and vim.fn.exists("+termkeyprotocol") == 1 then
  vim.o.termkeyprotocol = "kitty"
end

require "nvchad.options"

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.scrolloff = 999 -- keep cursor vertically centered (like zz)

if vim.g.neovide then
  vim.o.guifont = "GeistMono Nerd Font:h16"
end

if not vim.g.vscode and vim.fn.exists("+termkeyprotocol") == 1 then
  vim.o.termkeyprotocol = "kitty"
end

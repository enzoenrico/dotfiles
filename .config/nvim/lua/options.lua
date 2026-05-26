require "nvchad.options"

if vim.g.neovide then
  vim.o.guifont = "GeistMono Nerd Font:h16"
end

if not vim.g.vscode and vim.fn.exists("+termkeyprotocol") == 1 then
  vim.o.termkeyprotocol = "kitty"
end

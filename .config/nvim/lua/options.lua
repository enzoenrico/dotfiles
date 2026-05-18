require "nvchad.options"

if not vim.g.vscode and vim.fn.exists("+termkeyprotocol") == 1 then
  vim.o.termkeyprotocol = "kitty"
end

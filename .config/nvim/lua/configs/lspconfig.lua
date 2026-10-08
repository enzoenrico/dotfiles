local nvchad_lsp = require "nvchad.configs.lspconfig"
nvchad_lsp.defaults()

local ok_blink, blink = pcall(require, "blink.cmp")
if ok_blink then
  vim.lsp.config("*", {
    capabilities = blink.get_lsp_capabilities(nvchad_lsp.capabilities),
  })
end

require("configs.swift").setup()

vim.lsp.enable "sourcekit"

-- Shift-K (normal-mode K) is the only docs popup. Automatic signature help is off.
local function show_cursor_info()
  local buf = vim.api.nvim_get_current_buf()
  local hover = vim.lsp.protocol.Methods.textDocument_hover
  for _, client in ipairs(vim.lsp.get_clients { bufnr = buf }) do
    if client:supports_method(hover, buf) then
      vim.lsp.buf.hover()
      return
    end
  end

  vim.diagnostic.open_float {
    bufnr = buf,
    scope = "cursor",
    focus = false,
    focusable = false,
  }
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end
    for _, lhs in ipairs { "K", "<S-k>" } do
      vim.keymap.set("n", lhs, show_cursor_info, {
        buffer = args.buf,
        desc = "Documentation under cursor",
      })
    end
  end,
})

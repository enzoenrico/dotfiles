require("nvchad.configs.lspconfig").defaults()
require("configs.swift").setup()

vim.lsp.enable { "html", "cssls", "sourcekit" }

-- NvChad on_attach does not map `K`; ensure hover matches Vim/LSP expectation (standalone).
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end
    local method = vim.lsp.protocol.Methods.textDocument_hover
    if client.supports_method(method, args.buf) then
      vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = args.buf, desc = "LSP hover" })
    end
  end,
})

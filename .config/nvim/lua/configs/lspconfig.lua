require("nvchad.configs.lspconfig").defaults()
require("configs.swift").setup()

vim.lsp.enable { "html", "cssls", "sourcekit" }

-- NvChad on_attach does not map `K`; prefer cursor diagnostics, then fall back to hover.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end
    local method = vim.lsp.protocol.Methods.textDocument_hover
    vim.keymap.set("n", "K", function()
      local float_bufnr = vim.diagnostic.open_float {
        bufnr = args.buf,
        scope = "cursor",
        focus = false,
      }

      if float_bufnr then
        return
      end

      for _, attached_client in ipairs(vim.lsp.get_clients { bufnr = args.buf }) do
        if attached_client.supports_method(method, args.buf) then
          vim.lsp.buf.hover()
          return
        end
      end
    end, { buffer = args.buf, desc = "Cursor diagnostics or LSP hover" })
  end,
})

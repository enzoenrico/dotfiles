local ft = {
  lua = { "stylua" },
}

if vim.fn.executable "swiftformat" == 1 then
  ft.swift = { "swiftformat" }
end

return {
  formatters_by_ft = ft,
}

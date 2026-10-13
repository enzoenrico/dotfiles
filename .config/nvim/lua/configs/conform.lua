local ft = {
  lua = { "stylua" },
}

if vim.fn.executable "swiftformat" == 1 then
  ft.swift = { "swiftformat" }
end

if vim.fn.executable "rustfmt" == 1 then
  ft.rust = { "rustfmt" }
end

return {
  formatters_by_ft = ft,
}

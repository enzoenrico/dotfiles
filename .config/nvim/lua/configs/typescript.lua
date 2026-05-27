--- TypeScript / React (TSX): LSP, treesitter parsers, and formatting — loaded on demand.
local M = {}

local TS_FTS = { "typescript", "typescriptreact" }

local TS_PARSERS = { "typescript", "tsx", "javascript", "jsx" }

local function ensure_mason_tools()
  if vim.fn.executable "typescript-language-server" == 1 then
    return
  end

  local ok, registry = pcall(require, "mason-registry")
  if not ok then
    return
  end

  pcall(registry.refresh, registry)

  local pkg_name = registry.has_package "typescript-language-server" and "typescript-language-server"
    or registry.has_package "vtsls" and "vtsls"

  if not pkg_name then
    return
  end

  local pkg = registry.get_package(pkg_name)
  if not pkg:is_installed() then
    pkg:install()
  end
end

function M.setup_lsp()
  vim.lsp.config("ts_ls", {
    filetypes = TS_FTS,
    settings = {
      typescript = {
        inlayHints = {
          includeInlayParameterNameHints = "all",
          includeInlayFunctionParameterTypeHints = true,
          includeInlayVariableTypeHints = true,
        },
        preferences = {
          importModuleSpecifierPreference = "non-relative",
        },
      },
      javascript = {
        inlayHints = {
          includeInlayParameterNameHints = "all",
          includeInlayFunctionParameterTypeHints = true,
          includeInlayVariableTypeHints = true,
        },
      },
    },
  })

  vim.lsp.enable("ts_ls")
end

function M.setup_treesitter()
  require("nvim-treesitter").install(TS_PARSERS)

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.tbl_contains(TS_FTS, vim.bo[buf].filetype) then
      pcall(vim.treesitter.start, buf)
    end
  end
end

function M.setup_format()
  if vim.fn.executable "prettier" ~= 1 then
    return
  end

  local ok, conform = pcall(require, "conform")
  if not ok then
    return
  end

  local formatters = { "prettier" }
  for _, ft in ipairs(TS_FTS) do
    conform.formatters_by_ft[ft] = formatters
  end
end

local setup_done = false

function M.setup()
  if setup_done then
    return
  end
  setup_done = true

  ensure_mason_tools()
  M.setup_lsp()
  M.setup_treesitter()
  M.setup_format()
end

return M

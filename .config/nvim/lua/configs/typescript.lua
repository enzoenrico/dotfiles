--- TypeScript, Tailwind, and web tooling, loaded on demand.
local M = {}

local TS_FTS = { "javascript", "javascriptreact", "typescript", "typescriptreact" }

local WEB_FTS = {
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "json",
  "jsonc",
  "html",
  "css",
  "scss",
  "less",
  "astro",
  "svelte",
  "vue",
  "graphql",
}

local WEB_PARSERS = {
  "astro",
  "css",
  "graphql",
  "html",
  "javascript",
  "jsdoc",
  "json",
  "scss",
  "svelte",
  "tsx",
  "typescript",
  "vue",
}

local MASON_TOOLS = {
  "css-lsp",
  "eslint-lsp",
  "html-lsp",
  "json-lsp",
  "prettier",
  "tailwindcss-language-server",
  "typescript-language-server",
}

local PACKAGE_SERVERS = {
  ["css-lsp"] = { "cssls" },
  ["eslint-lsp"] = { "eslint" },
  ["html-lsp"] = { "html" },
  ["json-lsp"] = { "jsonls" },
  ["tailwindcss-language-server"] = { "tailwindcss" },
  ["typescript-language-server"] = { "ts_ls" },
}

local function enable_package_servers(package_name)
  for _, server in ipairs(PACKAGE_SERVERS[package_name] or {}) do
    vim.lsp.enable(server)
  end
end

local function ensure_mason_tools()
  local ok, registry = pcall(require, "mason-registry")
  if not ok then
    return
  end

  local function install_missing()
    for _, package_name in ipairs(MASON_TOOLS) do
      if registry.has_package(package_name) then
        local package = registry.get_package(package_name)
        if not package:is_installed() and not package:is_installing() then
          package:once("install:success", function()
            vim.schedule(function()
              enable_package_servers(package_name)
            end)
          end)
          package:install()
        end
      end
    end
  end

  registry.refresh(install_missing)
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

  vim.lsp.config("tailwindcss", {
    root_markers = {
      "tailwind.config.js",
      "tailwind.config.cjs",
      "tailwind.config.mjs",
      "tailwind.config.ts",
      "postcss.config.js",
      "package.json",
      ".git",
    },
  })

  vim.lsp.config("eslint", {
    settings = {
      workingDirectory = { mode = "auto" },
    },
  })

  local executables = {
    cssls = "vscode-css-language-server",
    eslint = "vscode-eslint-language-server",
    html = "vscode-html-language-server",
    jsonls = "vscode-json-language-server",
    tailwindcss = "tailwindcss-language-server",
    ts_ls = "typescript-language-server",
  }

  for server, executable in pairs(executables) do
    if vim.fn.executable(executable) == 1 then
      vim.lsp.enable(server)
    end
  end
end

function M.setup_treesitter()
  local ts = require "nvim-treesitter"
  if type(ts.install) == "function" then
    -- nvim-treesitter main
    ts.install(WEB_PARSERS)
  else
    -- nvim-treesitter master fallback
    local ok, install = pcall(require, "nvim-treesitter.install")
    if ok and install.ensure_installed then
      install.ensure_installed(WEB_PARSERS)
    end
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.tbl_contains(WEB_FTS, vim.bo[buf].filetype) then
      pcall(vim.treesitter.start, buf)
    end
  end
end

function M.setup_format()
  local ok, conform = pcall(require, "conform")
  if not ok then
    return
  end

  local formatters = { "prettier" }
  for _, ft in ipairs(WEB_FTS) do
    conform.formatters_by_ft[ft] = formatters
  end
end

local setup_done = false

function M.setup()
  if setup_done then
    return
  end
  setup_done = true

  M.setup_lsp()
  ensure_mason_tools()
  M.setup_treesitter()
  M.setup_format()
end

return M

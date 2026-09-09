--- Format plus LSP auto-import (add missing, then organize).

local M = {}

local TIMEOUT_MS = 1500

---@type string[]
local SOURCE_KINDS = {
  "source.addMissingImports",
  "source.organizeImports",
}

---@param action_kind string?
---@param wanted string
---@return boolean
local function kind_matches(action_kind, wanted)
  if type(action_kind) ~= "string" then
    return false
  end
  return action_kind == wanted or vim.startswith(action_kind, wanted .. ".")
end

---@param bufnr integer
---@return lsp.Range
local function full_buffer_range(bufnr)
  local last = math.max(vim.api.nvim_buf_line_count(bufnr), 1)
  local last_line = vim.api.nvim_buf_get_lines(bufnr, last - 1, last, true)[1] or ""
  return {
    start = { line = 0, character = 0 },
    ["end"] = { line = last - 1, character = #last_line },
  }
end

---@param client vim.lsp.Client
---@param action table
---@param bufnr integer
local function apply_action(client, action, bufnr)
  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
    return
  end

  local command = action.command
  if type(command) == "table" then
    client:exec_cmd(command, { bufnr = bufnr })
    return
  end

  if type(action.command) == "string" then
    client:exec_cmd(action, { bufnr = bufnr })
  end
end

---@param client vim.lsp.Client
---@param action table
---@param bufnr integer
local function apply_or_resolve(client, action, bufnr)
  if action.edit or action.command then
    apply_action(client, action, bufnr)
    return
  end

  local resolve = vim.lsp.protocol.Methods.codeAction_resolve
  if not client:supports_method(resolve, bufnr) then
    return
  end

  local resp = client:request_sync(resolve, action, TIMEOUT_MS, bufnr)
  if resp and resp.result then
    apply_action(client, resp.result, bufnr)
  end
end

---@param bufnr integer
---@param kind string
local function apply_source_kind(bufnr, kind)
  local method = vim.lsp.protocol.Methods.textDocument_codeAction
  local clients = vim.lsp.get_clients { bufnr = bufnr, method = method }

  for _, client in ipairs(clients) do
    local params = {
      textDocument = vim.lsp.util.make_text_document_params(bufnr),
      range = full_buffer_range(bufnr),
      context = {
        only = { kind },
        diagnostics = {},
      },
    }

    local resp = client:request_sync(method, params, TIMEOUT_MS, bufnr)
    local actions = resp and resp.result or {}
    for _, action in ipairs(actions) do
      if kind_matches(action.kind, kind) or (#actions == 1 and action.kind == nil) then
        apply_or_resolve(client, action, bufnr)
      end
    end
  end
end

---@param bufnr? integer
function M.apply_imports(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  for _, kind in ipairs(SOURCE_KINDS) do
    apply_source_kind(bufnr, kind)
  end
end

---@param opts? table
function M.format(opts)
  opts = vim.tbl_extend("force", { lsp_fallback = true }, opts or {})
  if not opts.range then
    M.apply_imports(opts.bufnr)
  end
  require("conform").format(opts)
end

return M

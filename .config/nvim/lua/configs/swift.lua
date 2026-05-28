--- Swift / SourceKit-LSP: keep highlighting and LSP usable while the buffer has parse errors.
local M = {}

local aug = vim.api.nvim_create_augroup("SwiftEditor", { clear = true })

--- Largest ERROR/MISSING node span in lines (0 when tree is clean).
local function largest_parse_fault_lines(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then
    return 0
  end

  local trees = parser:parse(true)
  if not trees[1] then
    return 0
  end

  local max_lines = 0

  local function walk(node)
    local t = node:type()
    if t == "ERROR" or t == "MISSING" then
      local sr, _, er, _ = node:range()
      max_lines = math.max(max_lines, er - sr + 1)
    end
    for child in node:iter_children() do
      walk(child)
    end
  end

  walk(trees[1]:root())
  return max_lines
end

function M.sync_syntax_fallback(buf)
  -- Single-line macro gaps (e.g. `#Preview`) are fine; multi-line faults need regex fallback.
  if largest_parse_fault_lines(buf) >= 2 then
    vim.bo[buf].syntax = "swift"
  elseif vim.bo[buf].syntax ~= "" then
    vim.bo[buf].syntax = ""
  end
end

function M.setup_lsp()
  -- NvChad's global on_init strips semantic tokens; SourceKit's survive incomplete Swift better.
  vim.lsp.config("sourcekit", {
    on_init = function() end,
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = aug,
    pattern = { "swift", "objc", "objcpp" },
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or client.name ~= "sourcekit" then
        return
      end
      if client:supports_method(vim.lsp.protocol.Methods.textDocument_semanticTokens_full) then
        vim.lsp.semantic_tokens.enable(true, args.buf)
      end
    end,
  })
end

function M.setup_treesitter()
  local timer

  local function refresh(buf)
    if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "swift" then
      return
    end
    pcall(vim.treesitter.start, buf)
    M.sync_syntax_fallback(buf)
  end

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = aug,
    pattern = "swift",
    callback = function(ev)
      if timer then
        vim.fn.timer_stop(timer)
      end
      timer = vim.fn.timer_start(100, function()
        refresh(ev.buf)
      end)
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = aug,
    pattern = "swift",
    callback = function(ev)
      refresh(ev.buf)
    end,
  })
end

function M.setup_diagnostics()
  vim.api.nvim_create_user_command("SwiftLspDiag", function()
    local buf = vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients { bufnr = buf, name = "sourcekit" }
    local lines = {}

    if #clients == 0 then
      vim.list_extend(lines, {
        "sourcekit: not attached to this buffer",
        "  → open a .swift file from the repo root (folder with buildServer.json)",
        "  → :XcodebuildSetup then build once (<leader>sb or Xcode)",
      })
    else
      local client = clients[1]
      lines[#lines + 1] = ("sourcekit: attached (root: %s)"):format(client.root_dir or "?")
      local bsp = (client.root_dir or "") .. "/buildServer.json"
      lines[#lines + 1] = ("buildServer.json: %s"):format(vim.fn.filereadable(bsp) == 1 and bsp or "missing at LSP root")
    end

    local pos = vim.api.nvim_win_get_cursor(0)
    local params = vim.lsp.util.make_position_params(0, "utf-16")
    local impl = vim.lsp.buf_request_sync(buf, "textDocument/implementation", params, 5000)
    local refs = vim.lsp.buf_request_sync(
      buf,
      "textDocument/references",
      vim.tbl_extend("force", params, { context = { includeDeclaration = false } }),
      5000
    )

    local function count_sync_response(response)
      if not response then
        return 0
      end
      local total = 0
      for _, item in pairs(response) do
        local result = item.result
        if result then
          total = total + (vim.islist(result) and #result or 1)
        end
      end
      return total
    end
    local impl_n = count_sync_response(impl)
    local refs_n = count_sync_response(refs)
    lines[#lines + 1] = ("at cursor L%d: implementations=%s, references=%s"):format(
      pos[1],
      impl_n,
      refs_n
    )
    lines[#lines + 1] = "gi: LSP implementations, then project declaration search when SourceKit returns none."
    if impl_n == 0 and refs_n > 0 then
      lines[#lines + 1] = "  → index OK; try <D-]> (references) or put cursor on the protocol name."
    elseif impl_n == 0 and refs_n == 0 then
      lines[#lines + 1] = "  → likely index/project: rebuild scheme, refresh buildServer.json, <leader>sR"
    end

    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Swift LSP" })
  end, { desc = "Diagnose SourceKit root + gi/refs at cursor" })
end

function M.setup_keymaps()
  vim.api.nvim_create_autocmd("FileType", {
    group = aug,
    pattern = "swift",
    callback = function()
      vim.keymap.set("n", "<leader>sR", function()
        local ok, lsp = pcall(require, "xcodebuild.integrations.lsp")
        if ok then
          lsp.restart_sourcekit_lsp()
        elseif vim.fn.exists(":LspRestart") == 2 then
          vim.cmd "LspRestart sourcekit"
        else
          vim.cmd "lsp restart sourcekit"
        end
        vim.notify("SourceKit-LSP restarted", vim.log.levels.INFO)
      end, { buffer = true, desc = "Restart SourceKit-LSP" })
    end,
  })
end

function M.setup()
  M.setup_lsp()
  M.setup_treesitter()
  M.setup_diagnostics()
  M.setup_keymaps()
end

return M

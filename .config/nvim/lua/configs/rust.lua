--- rust-analyzer for Cargo projects, and for LeetCode snippets that have no Cargo.toml.
local M = {}

local aug = vim.api.nvim_create_augroup("leetcode_rust_analyzer", { clear = true })

local function leetcode_dir()
  return vim.fs.normalize(vim.fn.stdpath "data" .. "/leetcode")
end

---@param path string
local function is_leetcode_file(path)
  if path == "" then
    return false
  end
  path = vim.fs.normalize(path)
  local dir = leetcode_dir()
  return path == dir or vim.startswith(path, dir .. "/")
end

local function client_capabilities()
  local shared = vim.lsp.config["*"]
  if shared and shared.capabilities then
    return vim.deepcopy(shared.capabilities)
  end

  local ok, blink = pcall(require, "blink.cmp")
  if ok then
    return blink.get_lsp_capabilities()
  end
  return vim.lsp.protocol.make_client_capabilities()
end

--- rust-analyzer ignores a file that is not in a crate unless it is passed as a detached file.
--- One client per file: every LeetCode solution shares a directory, and detachedFiles is fixed at startup.
---@param bufnr integer
function M.start_detached(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.b[bufnr].leetcode_rust_analyzer_started then
    return
  end

  local path = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
  if not is_leetcode_file(path) then
    return
  end

  vim.b[bufnr].leetcode_rust_analyzer_started = true

  local client_id = vim.lsp.start({
    name = "rust_analyzer",
    cmd = { "rust-analyzer" },
    root_dir = vim.fs.dirname(path),
    capabilities = client_capabilities(),
    init_options = {
      detachedFiles = { path },
      checkOnSave = false,
    },
    settings = {
      ["rust-analyzer"] = {
        checkOnSave = false,
      },
    },
  }, {
    bufnr = bufnr,
    reuse_client = function(client, config)
      if client.name ~= config.name or client:is_stopped() then
        return false
      end
      return vim.deep_equal(
        vim.tbl_get(client.config, "init_options", "detachedFiles"),
        vim.tbl_get(config, "init_options", "detachedFiles")
      )
    end,
  })

  if not client_id then
    vim.b[bufnr].leetcode_rust_analyzer_started = false
    return
  end

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    callback = function()
      local client = vim.lsp.get_client_by_id(client_id)
      if not client or client:is_stopped() then
        return
      end
      if #vim.lsp.get_buffers_by_client_id(client_id) <= 1 then
        client:stop()
      end
    end,
  })
end

function M.setup()
  local defaults = vim.lsp.config.rust_analyzer
  local default_root = defaults and defaults.root_dir

  -- Cargo root detection never calls on_dir for these files, so the project client stays off them.
  vim.lsp.config("rust_analyzer", {
    root_dir = function(bufnr, on_dir)
      if is_leetcode_file(vim.api.nvim_buf_get_name(bufnr)) then
        return
      end
      if type(default_root) == "function" then
        default_root(bufnr, on_dir)
      elseif default_root then
        on_dir(default_root)
      end
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = aug,
    pattern = "rust",
    callback = function(args)
      M.start_detached(args.buf)
    end,
  })
end

return M

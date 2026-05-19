-- Standalone Neovim: Cursor-like windowing, sidebar, terminal, LSP, leader maps.
-- Not loaded when `vim.g.vscode` (see `lua/mappings.lua`).

if vim.g.vscode then
  return
end

local map = vim.keymap.set

-- Window focus: Ctrl+Shift + hjkl (NvChad bare <C-hjkl> unchanged)
map("n", "<C-S-h>", "<C-w>h", { desc = "Focus left window", silent = true })
map("n", "<C-S-j>", "<C-w>j", { desc = "Focus below window", silent = true })
map("n", "<C-S-k>", "<C-w>k", { desc = "Focus above window", silent = true })
map("n", "<C-S-l>", "<C-w>l", { desc = "Focus right window", silent = true })

-- Move window far: Ctrl+Shift + arrows (avoids duplicating the same bytes as <C-S-h> vs move-left)
map("n", "<C-S-Left>", "<C-w>H", { desc = "Move window far left", silent = true })
map("n", "<C-S-Down>", "<C-w>J", { desc = "Move window far down", silent = true })
map("n", "<C-S-Up>", "<C-w>K", { desc = "Move window far up", silent = true })
map("n", "<C-S-Right>", "<C-w>L", { desc = "Move window far right", silent = true })

-- Swap window with next
map("n", "<C-S-x>", "<C-w>x", { desc = "Swap window with next", silent = true })

-- Bottom panel: Ctrl+` → horizontal bottom terminal (NvChad)
map({ "n", "t" }, "<C-`>", function()
  require("nvchad.term").toggle { pos = "sp", id = "htoggleTerm" }
end, { desc = "Toggle bottom terminal (Cursor panel)" })

-- Alternate: Shift+Alt+j → same toggle (Alt = Meta)
map({ "n", "t" }, "<M-J>", function()
  require("nvchad.term").toggle { pos = "sp", id = "htoggleTerm" }
end, { desc = "Toggle bottom terminal (Shift+Alt+j parity)" })

-- Sidebar: Alt+Cmd+s → NvimTreeToggle (+ NvChad fallbacks stay on <C-n> / <leader>e)
map("n", "<M-D-s>", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle sidebar (Cursor Alt+Cmd+s)" })

-- Command palette / quick open (Cursor Cmd+Shift+P / Cmd+P)
map("n", "<D-p>", "<cmd>Telescope find_files<CR>", { desc = "Quick open (Cursor Cmd+P)" })
map("n", "<S-D-p>", "<cmd>Telescope commands<CR>", { desc = "Command palette (Cursor Cmd+Shift+P)" })

-- Command palette (Space ;)
map("n", "<leader>;", "<cmd>Telescope commands<CR>", { desc = "Command palette" })

local function latest_cursor_plan()
  local plans_dir = vim.fn.expand "~/.cursor/plans"
  local files = vim.fn.globpath(plans_dir, "*.plan.md", false, true)
  if #files == 0 then
    return nil, "No plans in " .. plans_dir
  end
  table.sort(files, function(a, b)
    return vim.fn.getftime(a) > vim.fn.getftime(b)
  end)
  return files[1]
end

vim.api.nvim_create_user_command("CursorPlan", function(opts)
  local plan, err = latest_cursor_plan()
  if not plan then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  local cmd = opts.bang and "edit" or "split"
  vim.cmd(("%s %s"):format(cmd, vim.fn.fnameescape(plan)))
end, { bang = true, desc = "Open latest Cursor plan (bang: current window)" })

map("n", "<leader>cp", function()
  local plan, err = latest_cursor_plan()
  if not plan then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  vim.cmd("split " .. vim.fn.fnameescape(plan))
end, { desc = "Open latest Cursor plan" })

-- Close current split/window only (buffer may stay open in other windows). Use <leader>x to kill buffer (NvChad).
map("n", "<leader>k", function()
  if #vim.api.nvim_tabpage_list_wins() == 1 then
    vim.notify("Only one window in this tab", vim.log.levels.INFO)
    return
  end
  vim.cmd "close"
end, { desc = "Close window / split", silent = true })

-- Problems
map("n", "<leader>p", "<cmd>Telescope diagnostics<CR>", { desc = "Problems / diagnostics" })

-- LSP: Cursor-style chords + keep gd/gD/gr from NvChad/LSP
map("n", "gr", function()
  require("custom.lsp_renamer")()
end, { desc = "Rename (Cursor gr)" })

map("n", "gi", function()
  require("telescope.builtin").lsp_implementations()
end, { desc = "LSP implementations (Telescope)" })

map("n", "<D-]>", function()
  require("telescope.builtin").lsp_references()
end, { desc = "LSP references (Cursor Cmd+])" })

map("n", "<S-D-]>", function()
  vim.cmd "split"
  vim.lsp.buf.definition()
end, { desc = "Definition in split (Cursor Shift+Cmd+])" })

-- Shift+Option+F slot (tmux): format when Conform is available
local function format_doc()
  require("conform").format { async = true, lsp_fallback = true }
end
map("n", "<M-F>", format_doc, { desc = "Format document (Shift+Opt+F slot)" })
map("n", "<M-S-f>", format_doc, { desc = "Format document (Shift+Opt+f)" })

-- Swift / xcodebuild (macOS): <leader>s* — only when plugin loads
if vim.fn.has "macunix" == 1 then
  map("n", "<leader>sb", function()
    local ok, a = pcall(require, "xcodebuild.actions")
    if ok then
      a.build()
    else
      vim.notify("xcodebuild.nvim not loaded — open a Swift file or :XcodebuildPicker", vim.log.levels.WARN)
    end
  end, { desc = "Xcodebuild: build" })

  map("n", "<leader>sr", function()
    local ok, a = pcall(require, "xcodebuild.actions")
    if ok then
      a.build_and_run()
    else
      vim.notify("xcodebuild.nvim not loaded", vim.log.levels.WARN)
    end
  end, { desc = "Xcodebuild: build & run" })

  map("n", "<leader>st", function()
    local ok, a = pcall(require, "xcodebuild.actions")
    if ok then
      a.run_tests()
    else
      vim.notify("xcodebuild.nvim not loaded", vim.log.levels.WARN)
    end
  end, { desc = "Xcodebuild: test" })

  map("n", "<leader>sl", function()
    local ok, a = pcall(require, "xcodebuild.actions")
    if ok then
      a.clean_build()
    else
      vim.notify("xcodebuild.nvim not loaded", vim.log.levels.WARN)
    end
  end, { desc = "Xcodebuild: clean build" })

  map("n", "<leader>sd", function()
    local ok, a = pcall(require, "xcodebuild.actions")
    if ok then
      a.select_device()
    else
      vim.notify("xcodebuild.nvim not loaded", vim.log.levels.WARN)
    end
  end, { desc = "Xcodebuild: select device" })

  map("n", "<leader>sp", function()
    local ok, a = pcall(require, "xcodebuild.actions")
    if ok then
      a.show_picker()
    else
      vim.cmd "XcodebuildPicker"
    end
  end, { desc = "Xcodebuild: action picker" })

  map("n", "<leader>sg", function()
    local ok, dap = pcall(require, "xcodebuild.integrations.dap")
    if ok then
      dap.build_and_debug()
    else
      vim.notify("xcodebuild DAP not loaded", vim.log.levels.WARN)
    end
  end, { desc = "Xcodebuild: build & debug" })
end

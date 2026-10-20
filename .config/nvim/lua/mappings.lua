require "nvchad.mappings"

pcall(vim.keymap.del, "n", "<leader>n")
pcall(vim.keymap.del, "n", "<leader>rn")

local map = vim.keymap.set

map({ "n", "x" }, "<leader>fm", function()
  require("custom.format").format()
end, { desc = "Format file and import deps" })

if vim.g.vscode then
  local has_vscode, vscode = pcall(require, "vscode")

  if has_vscode then
    map({ "n", "v" }, "s", function()
      local ok = pcall(vscode.call, "flash-jump.flash")
      if not ok then
        local ok_flash, flash = pcall(require, "flash")
        if ok_flash then
          flash.jump()
        end
      end
    end, { desc = "Flash jump (VS Code or fallback)" })

    local function vs_go(action, fallback)
      return function()
        vscode.action(action, {
          callback = function(err)
            if err and fallback then
              vscode.action(fallback)
            end
          end,
        })
      end
    end

    map(
      "n",
      "gd",
      vs_go("editor.action.goToDefinition", "editor.action.revealDefinition"),
      { desc = "Go to definition (Cursor / VS Code)" }
    )
    map(
      "n",
      "g}",
      vs_go("editor.action.revealDefinitionAside", "editor.action.goToDefinition"),
      { desc = "Definition aside (vertical split)" }
    )
    map("n", "gi", vs_go "editor.action.goToImplementation", { desc = "Go to implementation (Cursor / VS Code)" })
    map("n", "gD", vs_go "editor.action.goToTypeDefinition", { desc = "Go to type definition (Cursor / VS Code)" })
    map("n", "gr", function()
      vscode.action "editor.action.rename"
    end, { desc = "Rename symbol (VS Code)" })

    map("n", "gg", function()
      vscode.action "cursorTop"
    end, { desc = "Go to top (VS Code)" })
  end

  local ok_cursors, cursors = pcall(require, "vscode-multi-cursor")
  if ok_cursors then
    local k = vim.keymap.set
    k({ "n", "x" }, "mc", cursors.create_cursor, { expr = true, desc = "Create cursor" })
    k({ "n" }, "mcc", cursors.cancel, { desc = "Cancel/Clear all cursors" })
    k({ "n", "x" }, "mi", cursors.start_left, { desc = "Start cursors on the left" })
    k({ "n", "x" }, "ma", cursors.start_right, { desc = "Start cursors on the right" })
    k({ "n" }, "[mc", cursors.prev_cursor, { desc = "Goto prev cursor" })
    k({ "n" }, "]mc", cursors.next_cursor, { desc = "Goto next cursor" })
    k({ "n" }, "mcs", cursors.flash_char, { desc = "Create cursor using flash" })
    k({ "n" }, "mcw", cursors.flash_word, { desc = "Create selection using flash" })
  end
else
  map({ "n", "x", "o" }, "s", function()
    require("flash").jump()
  end, { desc = "Flash jump" })
  map("n", "<leader>sj", function()
    require("flash").treesitter()
  end, { desc = "Flash Treesitter" })

  -- Splits: <leader> t then h / v; terminal: <leader> t t. Drop NvChad <leader>h/v (those opened terminals).
  pcall(vim.keymap.del, "n", "<leader>h")
  pcall(vim.keymap.del, "n", "<leader>v")
  map("n", "<leader>th", "<C-w>s", { desc = "Horizontal split" })
  map("n", "<leader>tv", "<C-w>v", { desc = "Vertical split" })
  -- Option+arrow moves the split divider in the arrow's direction, whichever side the cursor is on.
  local function move_divider(dir)
    local vertical = dir == "h" or dir == "l"
    local edge = vertical and "l" or "j"
    local has_next = vim.fn.winnr(edge) ~= vim.fn.winnr()
    local has_prev = vim.fn.winnr(vertical and "h" or "k") ~= vim.fn.winnr()
    -- Without a split on this axis, resize steals rows from the cmdline and pushes the statusline up.
    if not has_next and not has_prev then
      return
    end
    local grow = (dir == edge) == has_next
    local step = vertical and 3 or 2
    vim.cmd((vertical and "vertical " or "") .. "resize " .. (grow and "+" or "-") .. step)
  end
  map("n", "<M-Left>", function() move_divider "h" end, { desc = "Move split divider left" })
  map("n", "<M-Right>", function() move_divider "l" end, { desc = "Move split divider right" })
  map("n", "<M-Up>", function() move_divider "k" end, { desc = "Move split divider up" })
  map("n", "<M-Down>", function() move_divider "j" end, { desc = "Move split divider down" })
  map("n", "<leader>md", "<cmd>MdRender float<cr>", { desc = "Markdown floating preview" })

  local open_file_browser = function()
    require("configs.file_browser").open()
  end
  map("n", "<leader>e", open_file_browser, { desc = "File browser" })

  require "cursor_parity"
end

local format = require "keymaps.formatArgs"
vim.keymap.set("n", "<leader>fp", format.format_parentheses, { desc = "Format function arguments" })

vim.keymap.set("n", "<C-u>", "<cmd>UndotreeToggle<CR>", { desc = "Undotree" })

local comment_header = require "custom.comment_header"
vim.api.nvim_create_autocmd("InsertEnter", {
  once = true,
  callback = function()
    vim.schedule(comment_header.setup)
  end,
})
map("i", "////", comment_header.expand, { desc = "Comment header snippet" })

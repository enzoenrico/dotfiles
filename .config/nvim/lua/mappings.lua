require "nvchad.mappings"

local map = vim.keymap.set

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
    map("n", "gi", vs_go("editor.action.goToImplementation"), { desc = "Go to implementation (Cursor / VS Code)" })
    map("n", "gD", vs_go("editor.action.goToTypeDefinition"), { desc = "Go to type definition (Cursor / VS Code)" })
    map("n", "gr", function()
      vscode.action("editor.action.rename")
    end, { desc = "Rename symbol (VS Code)" })

    map("n", "gg", function()
      vscode.action("cursorTop")
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
  map({ "n", "t" }, "<leader>tt", function()
    require("nvchad.term").toggle { pos = "sp", id = "htoggleTerm" }
  end, { desc = "Toggle bottom terminal" })

  require "cursor_parity"
end

local format = require "keymaps.formatArgs"
vim.keymap.set("n", "<leader>fp", format.format_parentheses, { desc = "Format function arguments" })

vim.keymap.set("n", "<C-u>", "<cmd>UndotreeToggle<CR>", { desc = "Undotree" })

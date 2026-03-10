require "nvchad.mappings"

local map = vim.keymap.set

if vim.g.vscode then
  local has_vscode, vscode = pcall(require, "vscode")

  if has_vscode then
    map({ 'n', 'v' }, 's', function()
      local ok = pcall(vscode.call, 'flash-jump.flash')
      if not ok then
        local ok_flash, flash = pcall(require, "flash")
        if ok_flash then flash.jump() end
      end
    end, { desc = 'Flash jump (VS Code or fallback)' })

    -- Let Neovim receive `g…` and then run Cursor/VS Code actions from inside Neovim.
    -- (These are the same actions you previously had bound as VS Code chords like `g d`.)
    map('n', 'gd', function() pcall(vscode.call, 'editor.action.revealDefinition') end,
      { desc = 'Go to definition (VS Code)' })
    map('n', 'gD', function() pcall(vscode.call, 'editor.action.goToTypeDefinition') end,
      { desc = 'Go to type definition (VS Code)' })
    map('n', 'gr', function() pcall(vscode.call, 'editor.action.rename') end,
      { desc = 'Rename symbol (VS Code)' })
    map('n', 'gg', function() pcall(vscode.call, 'cursorTop') end,
      { desc = 'Go to top (VS Code)' })
  end

  local ok_cursors, cursors = pcall(require, 'vscode-multi-cursor')
  if ok_cursors then
    local k = vim.keymap.set
    k(
      { 'n', 'x' },
      'mc',
      cursors.create_cursor,
      { expr = true, desc = 'Create cursor' }
    )
    k(
      { 'n' },
      'mcc',
      cursors.cancel,
      { desc = 'Cancel/Clear all cursors' }
    )
    k(
      { 'n', 'x' },
      'mi',
      cursors.start_left,
      { desc = 'Start cursors on the left' }
    )
    k({ 'n', 'x' }, 'ma', cursors.start_right, { desc = 'Start cursors on the right' })
    k({ 'n' }, '[mc', cursors.prev_cursor, { desc = 'Goto prev cursor' })
    k({ 'n' }, ']mc', cursors.next_cursor, { desc = 'Goto next cursor' })
    k(
      { 'n' },
      'mcs',
      cursors.flash_char,
      { desc = 'Create cursor using flash' }
    )
    k(
      { 'n' },
      'mcw',
      cursors.flash_word,
      { desc = 'Create selection using flash' }
    )
  end
else
  map({ 'n', 'x', 'o' }, 's', function() require('flash').jump() end, { desc = 'Flash jump' })
end


-- Break arguments in parenthesis
local format = require('keymaps.formatArgs')

vim.keymap.set('n', '<C-m>', format.format_parentheses,
  { desc = 'Format function arguments' })
vim.keymap.set('n', '<CR>', '', { noremap = true })

# Modifier audit (WezTerm → tmux → Neovim)

Primary fix for **Cmd / `<D-…>` not working**: in [`options.lua`](/Users/enzoenrico/.config/nvim/lua/options.lua) set **`vim.o.termkeyprotocol = "kitty"`** when supported (**Neovim 0.10+**) so Neovim negotiates the kitty keyboard protocol even when **`TERM`** is `screen*` / `tmux*` (auto-detection skips and Super never binds). On older Neovim, upgrade or run **outside tmux**.

Also required: **WezTerm** `enable_kitty_keyboard = true` and **`Chain(DisableDefaultAssignment, SendKey)`** for SUPER chords in [`wezterm.lua`](/Users/enzoenrico/.config/wezterm/wezterm.lua).

**tmux**: keep default **`TERM`** (`tmux` / `tmux-256color`). Do not force `default-terminal "wezterm"` or import outer `TERM` into the session — that caused confusing terminal identification. Neovim relies on **`termkeyprotocol`**, not tmux lying about the terminal type.

## WezTerm (`~/.config/wezterm/wezterm.lua`)

- **`DisableDefaultAssignment`** on chords that still use **Cmd** so WezTerm forwards them: **Alt+Cmd+s**, **Cmd+]**, **Shift+Cmd+]**, **Cmd+P**, **Cmd+Shift+P**. Window focus/move use **Ctrl+Shift** inside Neovim (see table below).

## tmux (`~/.tmux.conf`)

Plain tmux: prefix bindings, mouse, history, TPM. No extended-keys overrides or global Ctrl pane-swaps (those interfered with shells and Neovim).

Restart tmux (`tmux kill-server` or a new session) after changes.

## Test inside Neovim (empty buffer)

Repeat for:

| Chord        | Intended action |
| ------------ | -------------------------------- |
| `<C-S-h>` … `<C-S-l>` | Focus split (`wincmd h/j/k/l`) |
| `<C-S-Left>` … `<C-S-Right>` (+ Up/Down) | Move window far (`wincmd H/J/K/L`) |
| `<M-D-s>`    | Sidebar (`NvimTreeToggle`) |
| `<D-p>` / `<S-D-p>` | Quick open / command palette (Telescope) |
| `<C-S-x>`    | Swap with next split (`<C-w>x`) |
| `<leader>th` / `<leader>tv` | Horizontal / vertical **buffer** split |
| `<leader>tt` | Toggle bottom terminal |
| `<leader>k`  | Close **window** only (`:close`); `<leader>x` closes **buffer** |
| `<C-\`>`     | Bottom terminal; `<A-h>` (NvChad) |

```vim
:verbose map <C-S-h>
```

## nvim-cmp (insert / cmdline where enabled)

| Chord | Action |
| ----- | ------ |
| `<Up>` / `<Down>` | Prev/next when completion visible |
| `<C-Space>` | Trigger completion — some terminals/IME eat **Ctrl+Space** (`:verbose imap <C-Space>`) |

## Shift + Alt + J

Bound as `<M-J>` in `cursor_parity.lua` (Meta + shifted **j**).

## Shift + Option + F

`<M-F>` and `<M-S-f>` run Conform format. Check with `:verbose map <M-F>` if your terminal sends something else.

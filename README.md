# dotfiles

Personal macOS config mirrored from `~/.config` and shell dotfiles.

## Quick start

```bash
# New machine: install repo configs into home
./install.sh

# After editing live ~/.config (or shell dotfiles): mirror into this repo
./sync.sh
git add -A && git commit -m "Sync configs from live home"

# API keys (not in git)
cp .secrets.zsh.example ~/.secrets.zsh
# Edit ~/.secrets.zsh with real values
```

`sync.sh` rsyncs applicable dirs from `~/.config/` into `.config/` (see excludes in the script), with Kitty synced explicitly from `~/.config/kitty/`.
`install.sh` pushes the repo copy back to `~/.config/` on a new machine, including Kitty into `~/.config/kitty/`.

## What is tracked

- Neovim, Karabiner, **Kanata** (keyboard remapping + Raycast toggle scripts), Aerospace, borders, WezTerm, fastfetch, scripts, Swift formatter config, fish, gh, and related essentials under `.config/` (iTerm2 App Support is excluded — it lives in `~/Library`)
- **Kitty** — `.config/kitty/kitty.conf` plus macOS appearance themes (`dark-theme.auto.conf`, `light-theme.auto.conf`, `no-preference-theme.auto.conf`; light/no-preference use Solarized Light) and `themes.conf` (Vesper palette reference)
- `.zshrc`, `.tmux.conf`, `.gitconfig`, `.gitignore_global`

## What is excluded

Top-level Raycast extensions (`~/.config/raycast/`), opencode `node_modules`, aider history, Karabiner automatic backups, and local secrets (`~/.secrets.zsh`).

## Kanata toggle (Raycast)

After `./install.sh` on a new machine:

```bash
~/.config/kanata/install-service.sh   # root LaunchDaemon (once)
~/.config/kanata/install-toggle.sh      # passwordless sudo helper (once)
```

In Raycast: **Settings → Extensions → Script Commands → Add Directories** → `~/.config/kanata/raycast/`. Use **Toggle Kanata** (optionally assign a hotkey).

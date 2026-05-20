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

`sync.sh` rsyncs applicable dirs from `~/.config/` into `.config/` (see excludes in the script).
`install.sh` pushes the repo copy back to `~/.config/` on a new machine.

## What is tracked

- Neovim, Karabiner, Aerospace, borders, Kitty, WezTerm, fastfetch, scripts, Swift formatter config, fish, gh, and related essentials under `.config/` (iTerm2 App Support is excluded — it lives in `~/Library`)
- `.zshrc`, `.tmux.conf`, `.gitconfig`, `.gitignore_global`

## What is excluded

Raycast extensions, opencode `node_modules`, aider history, Karabiner automatic backups, and local secrets (`~/.secrets.zsh`).

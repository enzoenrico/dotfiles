#!/usr/bin/env bash
# Push dotfiles from this repo to ~/.config and home directory.
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

RSYNC_EXCLUDES=(
  --exclude '.git'
  --exclude 'node_modules'
  --exclude '.cursor'
  --exclude '.tmp.*'
  --exclude 'raycast'
  --exclude 'opencode'
  --exclude 'aider'
  --exclude 'vercel-plugin'
  --exclude 'automatic_backups'
  --exclude '.aider.*'
  --exclude 'configstore'
  --exclude 'nvim/nvim'
  # Accidental duplicate config dir (~/.config/kitty/kitty/); not used by kitty
  --exclude 'kitty/kitty'
)

mkdir -p "$HOME/.config"
rsync -av "${RSYNC_EXCLUDES[@]}" \
  "$DOTFILES/.config/" "$HOME/.config/"

cp "$DOTFILES/.zshrc" "$HOME/.zshrc"
cp "$DOTFILES/.tmux.conf" "$HOME/.tmux.conf"
cp "$DOTFILES/.gitconfig" "$HOME/.gitconfig"
cp "$DOTFILES/.gitignore_global" "$HOME/.gitignore_global"

if [[ ! -f "$HOME/.secrets.zsh" ]]; then
  echo "Tip: cp $DOTFILES/.secrets.zsh.example ~/.secrets.zsh and add your API keys"
fi

if ! command -v anifetch >/dev/null 2>&1; then
  echo "Tip: anifetch startup needs: brew install chafa ffmpeg && uv tool install anifetch-cli"
fi

echo "Installed dotfiles from $DOTFILES"

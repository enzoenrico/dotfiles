#!/usr/bin/env bash
# Pull live ~/.config and shell dotfiles into this repo.
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
  --exclude 'kitty/kitty'
)

rsync -av --delete "${RSYNC_EXCLUDES[@]}" \
  "$HOME/.config/" "$DOTFILES/.config/"

cp "$HOME/.zshrc" "$DOTFILES/.zshrc"
cp "$HOME/.tmux.conf" "$DOTFILES/.tmux.conf"

# Sanitize secrets in repo copy of .zshrc
"$DOTFILES/scripts/sanitize-zshrc.sh" "$DOTFILES/.zshrc"

echo "Synced live configs into $DOTFILES"

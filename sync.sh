#!/usr/bin/env bash
# Pull live ~/.config and shell dotfiles into this repo.
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

RSYNC_EXCLUDES=(
  --exclude '.git'
  --exclude 'node_modules'
  --exclude '.cursor'
  --exclude '.tmp.*'
  --exclude '/raycast/'
  --exclude 'opencode'
  --exclude 'aider'
  --exclude 'vercel-plugin'
  --exclude 'automatic_backups'
  --exclude '.aider.*'
  --exclude 'configstore'
  --exclude 'nvim/nvim'
  --exclude 'kitty'
)

rsync -av --delete "${RSYNC_EXCLUDES[@]}" \
  "$HOME/.config/" "$DOTFILES/.config/"

if [[ -f "$HOME/Library/LaunchAgents/com.kyou.borders-appearance-watcher.plist" ]]; then
  sed "s|$HOME|__HOME__|g" \
    "$HOME/Library/LaunchAgents/com.kyou.borders-appearance-watcher.plist" \
    > "$DOTFILES/.config/borders/com.kyou.borders-appearance-watcher.plist"
fi

# Kitty terminal (~/.config/kitty)
mkdir -p "$DOTFILES/.config/kitty"
rsync -av --delete --exclude 'kitty/' \
  "$HOME/.config/kitty/" "$DOTFILES/.config/kitty/"

cp "$HOME/.zshrc" "$DOTFILES/.zshrc"
cp "$HOME/.tmux.conf" "$DOTFILES/.tmux.conf"
cp "$HOME/.gitconfig" "$DOTFILES/.gitconfig"
cp "$HOME/.gitignore_global" "$DOTFILES/.gitignore_global"

# Sanitize secrets and stale machine paths in repo copies
"$DOTFILES/scripts/sanitize-zshrc.sh" "$DOTFILES/.zshrc"
"$DOTFILES/scripts/sanitize-zshrc.sh" "$DOTFILES/.gitconfig"

echo "Synced live configs into $DOTFILES"

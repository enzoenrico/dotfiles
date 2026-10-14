#!/usr/bin/env bash
set -euo pipefail

BORDERS_DIR="$HOME/.config/borders"
LABEL="com.kyou.borders-appearance-watcher"
PLIST_SRC="$BORDERS_DIR/com.kyou.borders-appearance-watcher.plist"
PLIST_DST="$HOME/Library/LaunchAgents/${LABEL}.plist"
DOMAIN="gui/$(id -u)"

"$BORDERS_DIR/build-watcher.sh"
chmod +x "$BORDERS_DIR/bordersrc"

mkdir -p "$HOME/Library/LaunchAgents"
sed "s|__HOME__|$HOME|g" "$PLIST_SRC" > "$PLIST_DST"

launchctl bootout "$DOMAIN/com.mitel.borders-appearance-watcher" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.mitel.borders-appearance-watcher.plist"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST_DST"
launchctl enable "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl kickstart -k "$DOMAIN/$LABEL"

echo "Registered $LABEL to start at login."

sleep 2
if pgrep -f "$BORDERS_DIR/borders-appearance-watcher" >/dev/null; then
  echo "Borders appearance watcher is running ($LABEL)."
else
  echo "Watcher may have failed. Check: tail /tmp/${LABEL}.err" >&2
  exit 1
fi

#!/bin/bash
# Install Kanata as a root LaunchDaemon (required on macOS for Karabiner VirtualHID).
set -euo pipefail

PLIST_SRC="$HOME/.config/kanata/com.mitel.kanata.plist"
PLIST_DST="/Library/LaunchDaemons/com.mitel.kanata.plist"
KANATA_BIN="/opt/homebrew/opt/kanata/bin/kanata"

if [[ ! -f "$PLIST_SRC" ]]; then
  echo "Missing $PLIST_SRC"
  exit 1
fi

echo "Stopping any running kanata (including debug/manual runs)..."
sudo killall kanata 2>/dev/null || true
brew services stop kanata 2>/dev/null || true
launchctl bootout "gui/$(id -u)/homebrew.mxcl.kanata" 2>/dev/null || true
sleep 1

echo "Installing root LaunchDaemon..."
sudo cp "$PLIST_SRC" "$PLIST_DST"
sudo chown root:wheel "$PLIST_DST"
sudo chmod 644 "$PLIST_DST"

echo "Validating config..."
sudo "$KANATA_BIN" --cfg "$HOME/.config/kanata/kanata.kbd" --check

echo "Loading service..."
sudo launchctl bootout system/com.mitel.kanata 2>/dev/null || true
sudo launchctl bootstrap system "$PLIST_DST"
sudo launchctl enable system/com.mitel.kanata
sudo launchctl kickstart -k system/com.mitel.kanata

sleep 2
if pgrep -x kanata >/dev/null; then
  echo "Kanata is running (pid $(pgrep -x kanata))."
  echo "Check logs: tail -f /opt/homebrew/var/log/kanata.log"
else
  echo "Kanata failed to start. Log:"
  tail -20 /opt/homebrew/var/log/kanata.log 2>/dev/null || true
  exit 1
fi

echo ""
echo "Also ensure System Settings → Privacy & Security → Input Monitoring"
echo "includes: $KANATA_BIN"
echo "Quit Karabiner-Elements while using Kanata on the built-in keyboard."

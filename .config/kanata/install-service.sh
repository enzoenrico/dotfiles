#!/bin/bash
# Install Kanata as a root LaunchDaemon (required on macOS for Karabiner VirtualHID).
# Config is always read from ~/.config/kanata/kanata.kbd for the logged-in user.
set -euo pipefail

KANATA_DIR="${HOME}/.config/kanata"
PLIST_SRC="${KANATA_DIR}/com.mitel.kanata.plist"
PLIST_DST="/Library/LaunchDaemons/com.mitel.kanata.plist"
LAUNCH_SCRIPT_SRC="${KANATA_DIR}/kanata-launch.sh"
KANATA_BIN="/opt/homebrew/opt/kanata/bin/kanata"
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
LAUNCH_SCRIPT_DST="${BREW_PREFIX}/bin/kanata-mitel-launch"

if [[ ! -f "$PLIST_SRC" ]]; then
  echo "Missing $PLIST_SRC"
  exit 1
fi
if [[ ! -x "$LAUNCH_SCRIPT_SRC" ]]; then
  echo "Missing or not executable: $LAUNCH_SCRIPT_SRC"
  exit 1
fi

echo "Stopping any running kanata (including debug/manual runs)..."
sudo killall kanata 2>/dev/null || true
brew services stop kanata 2>/dev/null || true
launchctl bootout "gui/$(id -u)/homebrew.mxcl.kanata" 2>/dev/null || true
sleep 1

echo "Installing launch wrapper -> ${LAUNCH_SCRIPT_DST}"
echo "  (reads ~/.config/kanata/kanata.kbd for the console user)"
sudo install -m 755 "$LAUNCH_SCRIPT_SRC" "$LAUNCH_SCRIPT_DST"

echo "Installing root LaunchDaemon..."
sudo cp "$PLIST_SRC" "$PLIST_DST"
sudo chown root:wheel "$PLIST_DST"
sudo chmod 644 "$PLIST_DST"

echo "Validating config at ${KANATA_DIR}/kanata.kbd..."
sudo "$KANATA_BIN" --cfg "${KANATA_DIR}/kanata.kbd" --check

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

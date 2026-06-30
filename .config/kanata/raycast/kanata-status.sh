#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Kanata Status
# @raycast.mode inline
# @raycast.packageName Kanata
# @raycast.icon ⌨️

# Optional parameters:
# @raycast.description Show whether Kanata keyboard remapping is active

set -euo pipefail

SERVICE="/usr/local/bin/kanata-mitel-service"

if [[ ! -x "${SERVICE}" ]]; then
  echo "Not installed — run ~/.config/kanata/install-toggle.sh"
  exit 0
fi

status="$(sudo "${SERVICE}" status)"
case "${status}" in
  running) echo "Kanata: ON" ;;
  stopped) echo "Kanata: OFF" ;;
  *) echo "Kanata: ${status}" ;;
esac

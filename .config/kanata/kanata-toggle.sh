#!/usr/bin/env bash
# Toggle Kanata keyboard remapping on/off.
set -euo pipefail

SERVICE="/usr/local/bin/kanata-mitel-service"

if [[ ! -x "${SERVICE}" ]]; then
  echo "Run ~/.config/kanata/install-toggle.sh first." >&2
  exit 1
fi

result="$(sudo "${SERVICE}" toggle)"
case "${result}" in
  running) echo "Kanata: ON" ;;
  stopped) echo "Kanata: OFF" ;;
  *) echo "${result}" ;;
esac

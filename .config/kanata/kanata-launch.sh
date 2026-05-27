#!/usr/bin/env bash
# Launch kanata with ~/.config/kanata/kanata.kbd for the logged-in console user.
# Used by the system LaunchDaemon (runs as root; cannot use ~ in the plist).
set -euo pipefail

kanata_bin="/opt/homebrew/opt/kanata/bin/kanata"
if [[ ! -x "$kanata_bin" ]]; then
  kanata_bin="$(command -v kanata || true)"
fi
[[ -n "$kanata_bin" && -x "$kanata_bin" ]] || {
  echo "kanata-launch: kanata binary not found" >&2
  exit 1
}

_kanata_console_home() {
  local user home
  user="$(stat -f '%Su' /dev/console 2>/dev/null || true)"
  if [[ -z "$user" || "$user" == "loginwindow" || "$user" == "root" ]]; then
    user="${SUDO_USER:-${USER:-}}"
  fi
  [[ -n "$user" ]] || return 1
  home="$(eval echo "~${user}")"
  [[ -d "$home" ]] || return 1
  printf '%s\n' "$home"
}

home="$(_kanata_console_home)" || {
  echo "kanata-launch: could not resolve console user home" >&2
  exit 1
}

cfg="${home}/.config/kanata/kanata.kbd"
[[ -r "$cfg" ]] || {
  echo "kanata-launch: missing config ${cfg}" >&2
  exit 1
}

cd "${home}/.config/kanata"
exec "$kanata_bin" --no-wait --cfg "$cfg"

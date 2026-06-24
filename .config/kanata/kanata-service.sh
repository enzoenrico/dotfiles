#!/usr/bin/env bash
# Privileged helper for toggling the com.mitel.kanata LaunchDaemon.
# Installed to /usr/local/bin/kanata-mitel-service by install-toggle.sh.
set -euo pipefail

readonly DAEMON_LABEL="com.mitel.kanata"
readonly DAEMON_DOMAIN="system/${DAEMON_LABEL}"
readonly PLIST="/Library/LaunchDaemons/${DAEMON_LABEL}.plist"

is_running() {
  pgrep -x kanata >/dev/null 2>&1
}

cmd_status() {
  if is_running; then
    echo "running"
  else
    echo "stopped"
  fi
}

cmd_stop() {
  launchctl disable "${DAEMON_DOMAIN}" 2>/dev/null || true
  launchctl bootout "${DAEMON_DOMAIN}" 2>/dev/null || true
  killall kanata 2>/dev/null || true
  sleep 0.5
  if is_running; then
    echo "failed to stop" >&2
    return 1
  fi
  echo "stopped"
}

cmd_start() {
  if [[ ! -f "${PLIST}" ]]; then
    echo "missing plist: ${PLIST}" >&2
    return 1
  fi

  launchctl enable "${DAEMON_DOMAIN}" 2>/dev/null || true
  launchctl bootstrap system "${PLIST}" 2>/dev/null || true
  launchctl kickstart -k "${DAEMON_DOMAIN}" 2>/dev/null || true

  for _ in {1..10}; do
    if is_running; then
      echo "running"
      return 0
    fi
    sleep 0.3
  done

  echo "failed to start; check /opt/homebrew/var/log/kanata.log" >&2
  return 1
}

cmd_toggle() {
  if is_running; then
    cmd_stop
  else
    cmd_start
  fi
}

usage() {
  echo "Usage: kanata-mitel-service {start|stop|status|toggle}" >&2
  exit 1
}

case "${1:-}" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  status) cmd_status ;;
  toggle) cmd_toggle ;;
  *) usage ;;
esac

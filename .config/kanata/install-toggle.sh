#!/usr/bin/env bash
# Install privileged helper + sudoers rule for passwordless Kanata toggling.
set -euo pipefail

KANATA_DIR="${HOME}/.config/kanata"
SERVICE_SRC="${KANATA_DIR}/kanata-service.sh"
SERVICE_DST="/usr/local/bin/kanata-mitel-service"
SUDOERS_FILE="/etc/sudoers.d/kanata-mitel"
USERNAME="$(whoami)"

if [[ ! -f "${SERVICE_SRC}" ]]; then
  echo "Missing ${SERVICE_SRC}"
  exit 1
fi

echo "Installing privileged helper -> ${SERVICE_DST}"
sudo install -d /usr/local/bin
sudo install -m 755 "${SERVICE_SRC}" "${SERVICE_DST}"

SUDOERS_CONTENT="${USERNAME} ALL=(ALL) NOPASSWD: ${SERVICE_DST}"
TMP_SUDOERS="$(mktemp)"
trap 'rm -f "${TMP_SUDOERS}"' EXIT
printf '%s\n' "${SUDOERS_CONTENT}" >"${TMP_SUDOERS}"
sudo visudo -cf "${TMP_SUDOERS}"
sudo install -m 440 "${TMP_SUDOERS}" "${SUDOERS_FILE}"

chmod +x "${KANATA_DIR}/kanata-toggle.sh"
chmod +x "${KANATA_DIR}/raycast/"*.sh

if [[ ! -x /opt/homebrew/bin/kanata-mitel-launch ]]; then
  echo ""
  echo "Warning: /opt/homebrew/bin/kanata-mitel-launch is missing."
  echo "Toggle-on may fail until you run: ${KANATA_DIR}/install-service.sh"
fi

echo ""
echo "Installed. Next steps:"
echo "  1. Raycast → Settings → Extensions → Script Commands → Add Directories"
echo "     Select: ${KANATA_DIR}/raycast/"
echo "  2. Run 'Toggle Kanata' from Raycast (assign a hotkey if you like)"
echo ""
echo "Test: ${KANATA_DIR}/kanata-toggle.sh"

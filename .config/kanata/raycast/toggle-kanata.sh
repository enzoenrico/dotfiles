#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Kanata
# @raycast.mode compact
# @raycast.packageName Kanata
# @raycast.icon ⌨️

# Optional parameters:
# @raycast.description Enable or disable Kanata keyboard remapping

set -euo pipefail

exec "${HOME}/.config/kanata/kanata-toggle.sh"

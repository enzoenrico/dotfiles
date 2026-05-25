# Start Kanata for the built-in MacBook keyboard when an interactive zsh opens.
# Uses sudo non-interactively so new shells never block on a password prompt.
_zsh_kanata_autostart() {
  [[ -o interactive ]] || return 0
  [[ "${KANATA_ZSH_AUTOSTART:-1}" == "1" ]] || return 0
  (( $+functions[_zsh_is_tooling_terminal] )) && _zsh_is_tooling_terminal && return 0

  pgrep -x kanata >/dev/null 2>&1 && return 0

  local kanata_bin="/opt/homebrew/opt/kanata/bin/kanata"
  local kanata_cfg="$HOME/.config/kanata/kanata.kbd"
  local kanata_log="${XDG_STATE_HOME:-$HOME/.local/state}/kanata/kanata.log"

  [[ -x "$kanata_bin" && -r "$kanata_cfg" ]] || return 0
  mkdir -p "${kanata_log:h}" 2>/dev/null || return 0

  if [[ -f /Library/LaunchDaemons/com.mitel.kanata.plist ]]; then
    sudo -n launchctl kickstart -k system/com.mitel.kanata >/dev/null 2>&1 &!
  else
    sudo -n "$kanata_bin" --no-wait --cfg "$kanata_cfg" >>"$kanata_log" 2>&1 &!
  fi
}

_zsh_kanata_autostart

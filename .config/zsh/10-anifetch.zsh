# Splash on interactive shells only (needs a real terminal for playback)

_anifetch_tmux_session_key() {
  [[ -n "${TMUX:-}" ]] || return 1
  local rest="${TMUX#*,}"
  print -r "${rest#*,}"
}

_anifetch_session_marker() {
  [[ -n "${TMUX:-}" ]] || return 1
  local key
  key=$(_anifetch_tmux_session_key) || return 1
  print -r "${XDG_CACHE_HOME:-$HOME/.cache}/anifetch/session-${key}"
}

_zsh_run_anifetch() {
  _zsh_terminal_ready || return 0
  # Skip Cursor/VS Code agent shells and zsh-env capture (no splash, avoids ioctl errors)
  (( $+functions[_zsh_is_tooling_terminal] )) && _zsh_is_tooling_terminal && return 0
  command -v anifetch >/dev/null || return 0

  local marker
  marker=$(_anifetch_session_marker 2>/dev/null)
  if [[ -n "$marker" && -f "$marker" ]]; then
    return 0
  fi

  local video="${ANIFETCH_VIDEO:-$HOME/Library/Application Support/anifetch/assets/example.mp4}"
  if [[ ! -f "$video" ]]; then
    video="$(python3 -c 'import anifetch, pathlib; print(pathlib.Path(anifetch.__file__).parent / "assets" / "example.mp4")' 2>/dev/null)"
  fi
  [[ -f "$video" ]] || return 0

  local tty config
  tty=$(_zsh_output_tty)
  config="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config-pokemon.jsonc"

  anifetch "$video" -c "$config" <"$tty" >"$tty" 2>&1

  if [[ -n "$marker" ]]; then
    mkdir -p "${marker:h}"
    : >"$marker"
  fi
}

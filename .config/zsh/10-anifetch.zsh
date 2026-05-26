# Splash on interactive shells only (needs a real terminal for playback)
# Inside tmux: once per pane (new window/tab), not per session id — tmux reuses $0, $1, …
# across server restarts, which left stale session-* markers blocking "main".

_anifetch_pane_marker() {
  [[ -n "${TMUX:-}" ]] || return 1
  local pane created
  pane=$(tmux display-message -p '#{pane_id}' 2>/dev/null) || return 1
  created=$(tmux display-message -p '#{session_created}' 2>/dev/null) || return 1
  print -r "${XDG_CACHE_HOME:-$HOME/.cache}/anifetch/s${created}-pane-${pane}"
}

_zsh_run_anifetch() {
  _zsh_terminal_ready || return 0
  # Skip Cursor/VS Code agent shells and zsh-env capture (no splash, avoids ioctl errors)
  (( $+functions[_zsh_is_tooling_terminal] )) && _zsh_is_tooling_terminal && return 0
  command -v anifetch >/dev/null || return 0

  local marker
  marker=$(_anifetch_pane_marker 2>/dev/null)
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

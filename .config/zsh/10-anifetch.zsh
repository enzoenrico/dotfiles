# Splash on interactive shells only (needs a real terminal for playback)
# Inside tmux: once per pane (new window/tab), not per session id — tmux reuses $0, $1, …
# across server restarts, which left stale session-* markers blocking "main".
#
# Deferred: prompt returns immediately; splash runs only after 1s with no tty input.
# macOS sched is integer seconds only; input watch uses zsh/zselect in a background job.

_anifetch_pane_marker() {
  [[ -n "${TMUX:-}" ]] || return 1
  local pane created
  pane=$(tmux display-message -p '#{pane_id}' 2>/dev/null) || return 1
  created=$(tmux display-message -p '#{session_created}' 2>/dev/null) || return 1
  print -r "${XDG_CACHE_HOME:-$HOME/.cache}/anifetch/s${created}-pane-${pane}"
}

_anifetch_cleanup_watch() {
  if [[ -n ${_anifetch_watch_pid:-} ]]; then
    kill $_anifetch_watch_pid 2>/dev/null
    unset _anifetch_watch_pid
  fi
  trap - USR1
  if (( ${ANIFETCH_WATCH_FD:-0} )); then
    exec {ANIFETCH_WATCH_FD}<&-
    unset ANIFETCH_WATCH_FD
  fi
  sched -1 _anifetch_play_deferred 2>/dev/null
  add-zsh-hook -d preexec _anifetch_cancel 2>/dev/null
}

_anifetch_clear_state() {
  unset _anifetch_video _anifetch_config _anifetch_marker _anifetch_cancelled
}

_anifetch_cancel() {
  _anifetch_cancelled=1
  _anifetch_cleanup_watch
  _anifetch_clear_state
}

# Runs in a subshell: signals parent if the tty becomes readable within $idle seconds.
_anifetch_watch_for_input() {
  emulate -L zsh
  zmodload zsh/zselect
  local fd=$1 parent=$2 idle=$3
  if zselect -t "$idle" -r 0 "$fd" 2>/dev/null; then
    kill -USR1 "$parent" 2>/dev/null
  fi
}

_anifetch_play() {
  local tty
  [[ -n "${_anifetch_video:-}" && -f "${_anifetch_video}" ]] || return 0
  [[ -n "${_anifetch_config:-}" && -f "${_anifetch_config}" ]] || return 0
  tty=$(_zsh_output_tty) || return 0

  anifetch "$_anifetch_video" -c "$_anifetch_config" <"$tty" >"$tty" 2>&1

  if [[ -n "$_anifetch_marker" ]]; then
    mkdir -p "${_anifetch_marker:h}"
    : >"$_anifetch_marker"
  fi
}

_anifetch_play_deferred() {
  if [[ -n ${_anifetch_cancelled:-} ]]; then
    _anifetch_cleanup_watch
    _anifetch_clear_state
    return
  fi
  _anifetch_cleanup_watch
  _anifetch_play
  _anifetch_clear_state
}

_anifetch_begin_watch() {
  local tty idle
  tty=$(_zsh_output_tty) || return 0
  idle=${ANIFETCH_IDLE_SECS:-1}

  zmodload -i zsh/sched
  autoload -Uz add-zsh-hook
  add-zsh-hook preexec _anifetch_cancel

  _anifetch_cancelled=

  if zmodload -F zsh/zselect 2>/dev/null; then
    trap '_anifetch_cancel' USR1
    exec {ANIFETCH_WATCH_FD}<"$tty"
    _anifetch_watch_for_input $ANIFETCH_WATCH_FD $$ "$idle" &!
    _anifetch_watch_pid=$!
    sched +$idle _anifetch_play_deferred
    return
  fi

  sched +$idle _anifetch_play_deferred
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

  _anifetch_video=$video
  _anifetch_config="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config-pokemon.jsonc"
  _anifetch_marker=$marker

  autoload -Uz add-zsh-hook
  # Wait for the first prompt so zle is ready and we do not compete with startup redraws.
  add-zsh-hook precmd _anifetch_begin_watch_once
}

_anifetch_begin_watch_once() {
  add-zsh-hook -d precmd _anifetch_begin_watch_once
  _anifetch_begin_watch
}

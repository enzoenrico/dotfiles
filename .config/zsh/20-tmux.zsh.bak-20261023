# Tmux session routing: main / main-2 / … (one session per attached Kitty window)
# vs a shared cursor-agents session (AI tooling)
_zsh_is_tooling_terminal() {
  [[ -n "${ZSH_TMUX_TOOLING:-}" ]] && return 0
  [[ -n "${CURSOR_AGENT:-}${CURSOR_CLI:-}${CURSOR_SANDBOX:-}" ]] && return 0
  [[ -n "${CLAUDECODE:-}${OPENCODE_AGENT:-}${AIDER_AGENT:-}" ]] && return 0
  case "${TERM_PROGRAM:-}" in
    cursor|Cursor) [[ -n "${CURSOR_TRACE_ID:-}${CURSOR_AGENT:-}" ]] && return 0 ;;
  esac
  return 1
}

_zsh_is_user_terminal() {
  [[ -n "${SSH_TTY:-}" ]] && return 0
  # Kitty 0.40+ no longer sets TERM_PROGRAM; detect via KITTY_* / TERM instead.
  [[ -n "${KITTY_PID:-}${KITTY_WINDOW_ID:-}" ]] && return 0
  [[ -n "${WEZTERM_PANE:-}${WEZTERM_UNIX_SOCKET:-}" ]] && return 0
  [[ -n "${GHOSTTY_RESOURCES_DIR:-}" ]] && return 0
  case "${TERM_PROGRAM:-}" in
    Apple_Terminal|Ghostty|Hyper|WarpTerminal|WezTerm|iTerm.app|kitty|rio|vscode|cursor|Cursor)
      return 0
      ;;
  esac
  case "${TERM:-}" in
    xterm-kitty|xterm-ghostty) return 0 ;;
  esac
  return 1
}

_zsh_autostarts_tmux() {
  command -v tmux >/dev/null || return 1
  [[ -z "${TMUX:-}" ]] || return 1
  # No interactive-TTY gate: Kitty and other terminals may not report -t 1
  # ZSH_TMUX_AUTOSTART_SCOPE: terminals-only (default) | wezterm-only | agents-only | everywhere
  case "${ZSH_TMUX_AUTOSTART_SCOPE:-terminals-only}" in
    wezterm-only) [[ "${TERM_PROGRAM:-}" == "WezTerm" ]]; return $? ;;
    agents-only)  _zsh_is_tooling_terminal; return $? ;;
    everywhere)   _zsh_is_user_terminal || _zsh_is_tooling_terminal; return $? ;;
    terminals-only|*) _zsh_is_user_terminal || _zsh_is_tooling_terminal; return $? ;;
  esac
}

_zsh_tmux_session_client_count() {
  tmux display-message -p -t "$1" '#{session_attached}' 2>/dev/null || print -r -- 0
}

# First Kitty/WezTerm/etc. uses `main`. Another OS window (second monitor)
# gets main-2, main-3, … so it does not share the already-attached session.
# Closing a window and opening a new one still resumes a detached session.
_zsh_tmux_unattached_user_session() {
  local base="$1"
  local name="$base"
  local n=2
  local attached
  while tmux has-session -t "$name" 2>/dev/null; do
    attached="$(_zsh_tmux_session_client_count "$name")"
    if [[ "${attached:-0}" -eq 0 ]]; then
      print -r -- "$name"
      return 0
    fi
    name="${base}-${n}"
    n=$((n + 1))
  done
  print -r -- "$name"
}

_zsh_tmux_attach_or_create() {
  local session="$1" window="$2"
  if tmux has-session -t "$session" 2>/dev/null; then
    [[ "$session" == cursor-agents ]] && tmux set-option -t "$session" remain-on-exit on 2>/dev/null
    tmux new-window -t "$session" -n "$window" -c "${PWD}"
    exec tmux attach-session -t "$session"
  else
    if [[ "$session" == cursor-agents ]]; then
      exec tmux new-session -s "$session" -n "$window" -c "${PWD}" \; set-option remain-on-exit on
    else
      exec tmux new-session -s "$session" -n "$window" -c "${PWD}"
    fi
  fi
}

_zsh_tmux_autostart() {
  if ! _zsh_autostarts_tmux; then
    return 0
  fi

  if _zsh_is_tooling_terminal; then
    _zsh_tmux_attach_or_create "cursor-agents" "agent-$$-${EPOCHSECONDS:-$(date +%s)}"
  else
    local _user_session="${TMUX_SESSION:-main}"
    [[ "$_user_session" == "cursor-agents" ]] && _user_session="main"
    # Explicit TMUX_SESSION=name still shares; unset (the Kitty default) isolates.
    [[ -z "${TMUX_SESSION:-}" ]] && _user_session="$(_zsh_tmux_unattached_user_session "$_user_session")"
    _zsh_tmux_attach_or_create "$_user_session" "win-$$"
  fi
}

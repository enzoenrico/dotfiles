# Tmux session routing: main (user) vs cursor-agents (Cursor / tooling)
_zsh_is_tooling_terminal() {
  [[ -n "${ZSH_TMUX_TOOLING:-}" ]] && return 0
  [[ -n "${CURSOR_AGENT:-}${CURSOR_CLI:-}${CURSOR_SANDBOX:-}" ]] && return 0
  [[ -n "${VSCODE_IPC_HOOK:-}${VSCODE_INJECTION:-}${VSCODE_GIT_IPC_HANDLE:-}" ]] && return 0
  case "${TERM_PROGRAM:-}" in
    vscode|cursor|Cursor) return 0 ;;
  esac
  return 1
}

_zsh_autostarts_tmux() {
  command -v tmux >/dev/null || return 1
  [[ -z "${TMUX:-}" ]] || return 1
  # No interactive-TTY gate: Kitty and other terminals may not report -t 1
  # ZSH_TMUX_AUTOSTART_SCOPE: everywhere (default) | wezterm-only | agents-only
  case "${ZSH_TMUX_AUTOSTART_SCOPE:-everywhere}" in
    wezterm-only) [[ "${TERM_PROGRAM:-}" == "WezTerm" ]]; return $? ;;
    agents-only)  _zsh_is_tooling_terminal; return $? ;;
    everywhere|*) return 0 ;;
  esac
}

_zsh_tmux_attach_or_create() {
  local session="$1" window="$2"
  # -A is only valid for new-session (attach-or-create), not new-window.
  if tmux has-session -t "$session" 2>/dev/null; then
    tmux new-window -t "$session" -n "$window" -c "${PWD}"
    exec tmux attach-session -t "$session"
  else
    exec tmux new-session -s "$session" -n "$window" -c "${PWD}"
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
    _zsh_tmux_attach_or_create "$_user_session" "win-$$"
  fi
}

# Drop empty tooling windows when the shell exits (inside tmux only)
if _zsh_is_tooling_terminal && [[ -n "${TMUX:-}" ]]; then
  trap 'tmux kill-window 2>/dev/null' EXIT
fi

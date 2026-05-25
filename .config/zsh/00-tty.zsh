# Terminal detection for UI startup (anifetch, powerlevel10k/gitstatus)

# Resolve a writable TTY (stdout, $TTY, or tmux pane_tty).
_zsh_output_tty() {
  [[ -t 1 ]] && { print -r /dev/fd/1; return 0 }
  [[ -n "${TTY:-}" && -w "${TTY}" ]] && { print -r "$TTY"; return 0 }
  if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]] && command -v tmux >/dev/null; then
    local ptty
    ptty=$(tmux display -p -t "${TMUX_PANE}" '#{pane_tty}' 2>/dev/null)
    [[ -n "$ptty" && -w "$ptty" ]] && { print -r "$ptty"; return 0 }
  fi
  return 1
}

# True when the shell has a TTY that supports winsize ioctls (not Cursor env capture).
_zsh_terminal_ready() {
  local tty
  tty=$(_zsh_output_tty) || return 1
  stty size <"$tty" >/dev/null 2>&1
}

_zsh_has_interactive_tty() {
  _zsh_terminal_ready
}

# OMZ/p10k call `setopt monitor` even when there is no controlling TTY.
_zsh_guard_job_control_setopt() {
  [[ -o interactive ]] || return 0
  _zsh_terminal_ready && return 0
  function setopt() {
    [[ "$1" == monitor ]] && return 0
    builtin setopt "$@"
  }
  function unsetopt() {
    [[ "$1" == monitor ]] && return 0
    builtin unsetopt "$@"
  }
}

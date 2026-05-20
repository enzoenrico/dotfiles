# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

plugins=(
	git
	zsh-autosuggestions
)

# pokemon-colorscripts --no-title -r | fastfetch -c ~/.config/fastfetch/config-pokemon.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo -
# anifetch replaces fastfetch on startup (see _run_startup_fetch below)

ZSH_THEME="robbyrussell"

source $ZSH/oh-my-zsh.sh

export PATH="$HOME/.local/bin:$PATH"

if [[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [[ -f "$ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

alias sail="./vendor/bin/sail"
alias ff='nvim $(fzf --preview="bat --color=always {}")'
alias venv="python3 -m venv .venv && source ./.venv/bin/activate"
alias lg="lazygit"



export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

autoload -Uz compinit

[[ -d "$HOME/code/flutter/bin" ]] && export PATH="$HOME/code/flutter/bin:$PATH"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if [[ -x "$HOME/miniconda3/bin/conda" ]]; then
  __conda_setup="$("$HOME/miniconda3/bin/conda" shell.zsh hook 2> /dev/null)"
  if [ $? -eq 0 ]; then
    eval "$__conda_setup"
  else
    if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
      . "$HOME/miniconda3/etc/profile.d/conda.sh"
    else
      export PATH="$HOME/miniconda3/bin:$PATH"
    fi
  fi
  unset __conda_setup
fi
# <<< conda initialize <<<

if JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null)"; then
  export JAVA_HOME
fi

# Claude Code / OpenRouter (secrets in ~/.secrets.zsh, not git)
# Load local secrets: cp dotfiles/.secrets.zsh.example ~/.secrets.zsh
[[ -f ~/.secrets.zsh ]] && source ~/.secrets.zsh

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme


[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

_anifetch_tmux_session_key() {
  [[ -n "${TMUX:-}" ]] || return 1
  # TMUX=/path/to/socket,server_pid,session_index — session_index is per-session
  local rest="${TMUX#*,}"
  print -r "${rest#*,}"
}

_anifetch_session_marker() {
  [[ -n "${TMUX:-}" ]] || return 1
  local key
  key=$(_anifetch_tmux_session_key) || return 1
  print -r "${XDG_CACHE_HOME:-$HOME/.cache}/anifetch/session-${key}"
}

# fd 1 is often not a TTY inside tmux (and some terminal emulators); use pane TTY.
_anifetch_output_tty() {
  [[ -t 1 ]] && { print -r /dev/fd/1; return 0 }
  [[ -n "${TTY:-}" && -w "${TTY}" ]] && { print -r "$TTY"; return 0 }
  if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]] && command -v tmux >/dev/null; then
    local ptty
    ptty=$(tmux display -p -t "${TMUX_PANE}" '#{pane_tty}' 2>/dev/null)
    [[ -n "$ptty" && -w "$ptty" ]] && { print -r "$ptty"; return 0 }
  fi
  return 1
}

_run_startup_fetch() {
  [[ -n "${ANIFETCH_SKIP:-}" ]] && return 1
  command -v anifetch >/dev/null || return 1

  local otty cols lines w h
  otty=$(_anifetch_output_tty) || return 1

  if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null; then
    # Pane size is reliable here; $COLUMNS/$LINES during .zshrc can be wrong on splits
    read -r cols lines <<<"$(tmux display -p -t "${TMUX_PANE}" '#{pane_width} #{pane_height}' 2>/dev/null)"
  fi
  cols=${cols:-${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}}
  lines=${lines:-${LINES:-$(tput lines 2>/dev/null || echo 24)}}
  # ~half terminal width; old -W 5 was for fastfetch logo cells, not video size
  w=$(( cols / 2 ))
  h=$(( lines * 3 / 5 ))
  (( w < 40 )) && w=40
  (( w > 100 )) && w=100
  (( h < 22 )) && h=22
  (( h > 45 )) && h=45

  local -a af_args=(
    example.mp4
    -c ~/.config/fastfetch/config-pokemon.jsonc
    -W "$w"
    -H "$h"
  )

  if [[ "$otty" == /dev/fd/1 ]]; then
    command anifetch "${af_args[@]}" -b &>/dev/null || return 1
    command anifetch "${af_args[@]}" --no-input-restore || return 1
  else
    command anifetch "${af_args[@]}" -b &>"$otty" || return 1
    command anifetch "${af_args[@]}" --no-input-restore <"$otty" >"$otty" 2>"$otty" || return 1
  fi
}

_run_startup_fetch_if_needed() {
  local marker
  marker=$(_anifetch_session_marker 2>/dev/null) || true
  [[ -n "$marker" && -f "$marker" ]] && return 0

  # Claim the session before fetch so pane/window splits skip immediately
  if [[ -n "$marker" ]]; then
    mkdir -p "${marker:h}"
    : >"$marker"
  fi

  _run_startup_fetch || {
    [[ -n "$marker" && -f "$marker" ]] && rm -f "$marker"
    return 1
  }
}

_anifetch_startup_precmd() {
  if _run_startup_fetch_if_needed; then
    precmd_functions=( ${precmd_functions:#_anifetch_startup_precmd} )
  elif (( ++_anifetch_precmd_tries > 12 )); then
    precmd_functions=( ${precmd_functions:#_anifetch_startup_precmd} )
  fi
}

_zsh_autostarts_tmux() {
  command -v tmux >/dev/null && [[ -t 1 ]] && [[ -z "${TMUX:-}" ]]
}

# Inside tmux: defer until the first pane is laid out; once per session (not splits).
# Outside tmux without autostart: run immediately. With autostart: skip here.
if [[ -n "${TMUX:-}" ]]; then
  precmd_functions+=( _anifetch_startup_precmd )
elif ! _zsh_autostarts_tmux; then
  _run_startup_fetch_if_needed
fi

if _zsh_autostarts_tmux; then
  if [[ -n "${CURSOR_AGENT:-}" ]]; then
    # Cursor agent shells share one session (windows); Prefix+Q kills the whole group
    _agent_session="cursor-agents"
    _agent_window="agent-$$-${EPOCHSECONDS:-$(date +%s)}"
    if tmux has-session -t "$_agent_session" 2>/dev/null; then
      exec tmux new-window -t "$_agent_session" -n "$_agent_window" -c "${PWD}" \; attach-session -t "$_agent_session"
    else
      exec tmux new-session -s "$_agent_session" -n "$_agent_window" -c "${PWD}"
    fi
  else
    # Interactive terminals: one session each (names must stay ASCII-safe for tmux)
    exec tmux new-session -s "term-$$-${EPOCHSECONDS:-$(date +%s)}-${RANDOM}"
  fi
fi

# bun completions
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# opencode
[[ -d "$HOME/.opencode/bin" ]] && export PATH="$HOME/.opencode/bin:$PATH"

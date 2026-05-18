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
source $ZSH/oh-my-zsh.sh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /Users/enzoenrico/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

alias sail="./vendor/bin/sail"
alias ff='nvim $(fzf --preview="bat --color=always {}")'
alias venv="python3 -m venv .venv && source ./.venv/bin/activate"

alias academy="cd ~/code/academy"
alias speech='cd ~/code/academy/speech-trainer && code ~/code/academy/speech-trainer'


export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

autoload -Uz compinit

export PATH=$HOME/code/flutter/bin:$PATH

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/enzoenrico/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/enzoenrico/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/enzoenrico/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/enzoenrico/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export JAVA_HOME=$(/usr/libexec/java_home)

# Claude Code / OpenRouter (secrets in ~/.secrets.zsh, not git)
# Load local secrets: cp dotfiles/.secrets.zsh.example ~/.secrets.zsh
[[ -f ~/.secrets.zsh ]] && source ~/.secrets.zsh

# pnpm
export PNPM_HOME="/Users/enzoenrico/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme


[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export PATH="$HOME/.local/bin:$PATH"

_anifetch_pane_marker() {
  [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]] || return 1
  print -r "${XDG_CACHE_HOME:-$HOME/.cache}/anifetch/pane-${TMUX_PANE//\//_}"
}

_run_startup_fetch() {
  [[ -t 1 ]] || return
  [[ -n "${CURSOR_AGENT:-}" ]] && return
  command -v anifetch >/dev/null || return

  local cols lines w h
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

  # -b builds/validates cache without printing status lines or starting the animation
  command anifetch "${af_args[@]}" -b &>/dev/null

  # Default loop (-1): animates until you press a key; --no-input-restore avoids replaying that key
  command anifetch "${af_args[@]}" --no-input-restore
}

_run_startup_fetch_if_needed() {
  local marker
  marker=$(_anifetch_pane_marker 2>/dev/null) || true
  [[ -n "$marker" && -f "$marker" ]] && return

  _run_startup_fetch

  [[ -n "$marker" ]] || return
  mkdir -p "${marker:h}"
  : >"$marker"
}

_anifetch_startup_precmd() {
  precmd_functions=( ${precmd_functions:#_anifetch_startup_precmd} )
  _run_startup_fetch_if_needed
}

_zsh_autostarts_tmux() {
  command -v tmux >/dev/null && [[ -t 1 ]] && [[ -z "${TMUX:-}" ]]
}

# Inside tmux: defer until the pane is laid out (splits/new windows). Outside tmux
# without autostart: run immediately. With autostart: skip here — new panes run it.
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
[ -s "/Users/enzoenrico/.bun/_bun" ] && source "/Users/enzoenrico/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# opencode
export PATH=/Users/enzoenrico/.opencode/bin:$PATH

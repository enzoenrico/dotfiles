export PATH="$HOME/.local/bin:$PATH"
_zsh_config="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
[[ -f "$_zsh_config/00-tty.zsh" ]] && source "$_zsh_config/00-tty.zsh"
[[ -f "$_zsh_config/05-kanata.zsh" ]] && source "$_zsh_config/05-kanata.zsh"

# Powerlevel10k instant prompt (needs a real TTY; skip IDE zsh-env capture)
if _zsh_terminal_ready && [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Tmux first (before OMZ/nvm/conda/anifetch) so Cursor/Kitty enter tmux immediately
_zsh_guard_job_control_setopt
[[ -f "$_zsh_config/20-tmux.zsh" ]] && source "$_zsh_config/20-tmux.zsh"
_zsh_tmux_autostart

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

plugins=(
	git
	zsh-autosuggestions
)

ZSH_THEME="robbyrussell"

source $ZSH/oh-my-zsh.sh

if [[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [[ -f "$ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

alias sail="./vendor/bin/sail"
alias ff='nvim $(fzf --preview="bat --color=always {}")'
alias venv="python3 -m venv .venv && source ./.venv/bin/activate"
alias lg="lazygit"
alias ndiff="nvim -c :DiffviewOpen ."
alias oc="opencode"



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
export PNPM_HOME="/Users/mitel/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

# gitstatus needs a real TTY; skip p10k during Cursor/IDE zsh-env capture
if _zsh_terminal_ready; then
  source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
  [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
fi

[[ -f "$_zsh_config/10-anifetch.zsh" ]] && source "$_zsh_config/10-anifetch.zsh"
_zsh_run_anifetch

# bun completions
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# opencode
[[ -d "$HOME/.opencode/bin" ]] && export PATH="$HOME/.opencode/bin:$PATH"

#!/usr/bin/env bash
# Point `grok` at the local grok-build fork when that binary exists.
# Otherwise use the installed CLI in ~/.grok/bin. A dangling link in
# ~/.local/bin makes zsh report "command not found".
set -euo pipefail

fork="${HOME}/code/open-source/grok-build/target/debug/xai-grok-pager"
installed="${HOME}/.grok/bin/grok"
link="${HOME}/.local/bin/grok"
cfg="${HOME}/.grok/config.toml"

target=""
if [[ -x "$fork" ]]; then
  target="$fork"
elif [[ -x "$installed" ]]; then
  target="$installed"
fi

if [[ -n "$target" ]]; then
  mkdir -p "${HOME}/.local/bin"
  if [[ "$(readlink "$link" 2>/dev/null || true)" != "$target" ]]; then
    ln -sfn "$target" "$link"
  fi
elif [[ -L "$link" ]]; then
  rm -f "$link"
fi

# Leave a machine alone until grok or the fork is present.
if [[ ! -x "$fork" && ! -d "${HOME}/.grok" ]]; then
  exit 0
fi

mkdir -p "${HOME}/.grok"
if [[ ! -f "$cfg" ]]; then
  printf '%s\n' '[cli]' 'backend = "cursor"' >"$cfg"
  exit 0
fi

tmp="$(mktemp)"
awk '
  function emit_backend() {
    print "backend = \"cursor\""
    wrote = 1
  }
  /^\[cli\][[:space:]]*$/ {
    if (in_cli && !wrote) emit_backend()
    in_cli = 1
    saw_cli = 1
    print
    next
  }
  /^\[/ {
    if (in_cli && !wrote) emit_backend()
    in_cli = 0
    print
    next
  }
  in_cli && /^[[:space:]]*backend[[:space:]]*=/ {
    emit_backend()
    next
  }
  { print }
  END {
    if (!saw_cli) {
      print ""
      print "[cli]"
      emit_backend()
    } else if (in_cli && !wrote) {
      emit_backend()
    }
  }
' "$cfg" >"$tmp"

if cmp -s "$tmp" "$cfg"; then
  rm -f "$tmp"
else
  mv "$tmp" "$cfg"
fi

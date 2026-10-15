#!/usr/bin/env bash
# Point `grok` at the local grok-build fork and select the cursor backend.
set -euo pipefail

fork="${HOME}/code/open-source/grok-build/target/debug/xai-grok-pager"
link="${HOME}/.local/bin/grok"
cfg="${HOME}/.grok/config.toml"

if [[ -x "$fork" ]]; then
  mkdir -p "${HOME}/.local/bin"
  if [[ "$(readlink "$link" 2>/dev/null || true)" != "$fork" ]]; then
    ln -sfn "$fork" "$link"
  fi
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

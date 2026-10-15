# Keep `grok` on the local grok-build fork with the cursor backend.
if [[ -o interactive ]]; then
  _grok_ensure="${XDG_CONFIG_HOME:-$HOME/.config}/grok/ensure.sh"
  [[ -x "$_grok_ensure" ]] && "$_grok_ensure"
  unset _grok_ensure
fi

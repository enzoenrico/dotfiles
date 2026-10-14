#!/usr/bin/env bash
set -euo pipefail

BORDERS_DIR="$HOME/.config/borders"
BINARY="$BORDERS_DIR/borders-appearance-watcher"
SOURCE="$BORDERS_DIR/appearance-watcher.swift"

SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Apple Development:.*\)".*/\1/p' \
    | head -1)"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "No Apple Development signing identity found." >&2
  exit 1
fi

swiftc -O -o "$BINARY" "$SOURCE" -framework AppKit -framework Foundation
codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$BINARY"

echo "Built and signed: $BINARY"
codesign -dv --verbose=2 "$BINARY" 2>&1 | sed -n '1,3p'

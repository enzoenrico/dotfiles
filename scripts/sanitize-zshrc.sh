#!/usr/bin/env bash
# Replace inline API secrets and stale home paths in tracked shell/git configs.
set -euo pipefail

TARGET="${1:-}"

if [[ -z "$TARGET" || ! -f "$TARGET" ]]; then
  echo "Usage: $0 <path-to-config-file>" >&2
  exit 1
fi

python3 - "$TARGET" <<'PY'
import re
import sys
from pathlib import Path

path = sys.argv[1]
text = open(path).read()

# Old machine username from a prior laptop sync
text = text.replace("/Users/enzoenrico/", str(Path.home()) + "/")
text = re.sub(
    r"excludesfile = /Users/[^/\s]+/\.gitignore_global",
    "excludesfile = ~/.gitignore_global",
    text,
)

block = """# Claude Code / OpenRouter (secrets in ~/.secrets.zsh, not git)
# Load local secrets: cp dotfiles/.secrets.zsh.example ~/.secrets.zsh
[[ -f ~/.secrets.zsh ]] && source ~/.secrets.zsh
"""

pattern = re.compile(
    r"#claude code config\n"
    r'export ANTHROPIC_BASE_URL="[^"]*"\n'
    r'export ANTHROPIC_AUTH_TOKEN="[^"]*"\n'
    r'export ANTHROPIC_API_KEY="[^"]*"[^\n]*\n'
    r'export ANTHROPIC_DEFAULT_SONNET_MODEL="[^"]*"[^\n]*\n',
    re.MULTILINE,
)

if pattern.search(text):
    text = pattern.sub(block, text)
elif "ANTHROPIC_AUTH_TOKEN=" in text and "~/.secrets.zsh" not in text:
    text = re.sub(
        r'export ANTHROPIC_AUTH_TOKEN="[^"]*"\n',
        "",
        text,
    )
    if "~/.secrets.zsh" not in text:
        text = text.replace(
            "export JAVA_HOME=$(/usr/libexec/java_home)\n",
            "export JAVA_HOME=$(/usr/libexec/java_home)\n\n" + block,
        )

open(path, "w").write(text)
PY

echo "Sanitized secrets in $TARGET"

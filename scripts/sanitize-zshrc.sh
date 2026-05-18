#!/usr/bin/env bash
# Replace inline API secrets in .zshrc with a source to ~/.secrets.zsh
set -euo pipefail

TARGET="${1:-}"

if [[ -z "$TARGET" || ! -f "$TARGET" ]]; then
  echo "Usage: $0 <path-to-.zshrc>" >&2
  exit 1
fi

python3 - "$TARGET" <<'PY'
import re
import sys

path = sys.argv[1]
text = open(path).read()

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

#!/usr/bin/env bash
set -euo pipefail

CURR_BRANCH="$(git branch --show-current)"
git switch develop
git pull
git switch "$CURR_BRANCH"
git rebase develop

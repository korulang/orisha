#!/usr/bin/env bash
# Install Orisha's git gates into this repo (or another one).
#
#   pre-commit — refuses a pure-Koru program living in a .kz file, and a `~`
#                in a .k file. Both are the same rule: the tilde is a parser
#                switch, and a file with no host language has nothing to switch.
#
# Usage:  hooks/install.sh [/path/to/repo]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TARGET="$(cd "${1:-$HERE/..}" && pwd)"
HOOKS="$(git -C "$TARGET" rev-parse --absolute-git-dir)/hooks"
mkdir -p "$HOOKS"
for h in pre-commit pre-commit.cjs; do
  cp "$HERE/$h" "$HOOKS/$h"; chmod +x "$HOOKS/$h"
done
echo "installed pre-commit -> $HOOKS"

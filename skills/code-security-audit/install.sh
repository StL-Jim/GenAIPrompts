#!/usr/bin/env bash
# SKILL VERSION: v2-skill (2026-08-14a) -- installer (bash / Git Bash)
#
# Clean-installs this skill into Claude Code's user skills directory. Unlike a plain
# `cp -r`, this REPLACES the target rather than merging into it, so a file removed from
# the repo cannot linger in the installed copy and be read by a later run.
#
#   bash skills/code-security-audit/install.sh              # default location
#   bash skills/code-security-audit/install.sh /some/path   # explicit target
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$HOME/.claude/skills/code-security-audit}"

# Safety: never let an empty or obviously wrong DEST reach `rm -rf`.
case "$DEST" in
  ""|"/"|"$HOME"|"$HOME/") echo "Refusing to install to '$DEST'." >&2; exit 1 ;;
esac
if [ "$(basename "$DEST")" != "code-security-audit" ]; then
  echo "Refusing: target must end in 'code-security-audit' (got '$DEST')." >&2; exit 1
fi
if [ ! -f "$SRC/SKILL.md" ]; then
  echo "Source does not look like the skill (no SKILL.md in $SRC)." >&2; exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST"
cp -pr "$SRC"/. "$DEST"/

grep -m1 -o 'SKILL VERSION: [^ ]*' "$DEST/SKILL.md" || true
echo "Installed code-security-audit to $DEST"
echo "Files: $(find "$DEST" -type f | wc -l | tr -d ' ')"

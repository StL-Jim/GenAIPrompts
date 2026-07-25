#!/usr/bin/env bash
# SKILL VERSION: v25-skill (2026-07-24j) -- installer (bash / Git Bash)
#
# Clean-installs this skill into Claude Code's user skills directory. Unlike a plain
# `cp -r`, this REPLACES the target rather than merging into it, so a file removed from
# the repo cannot linger in the installed copy and be read by a later run.
#
#   bash skills/stride-threat-model/install.sh              # default location
#   bash skills/stride-threat-model/install.sh /some/path   # explicit target
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$HOME/.claude/skills/stride-threat-model}"

# Safety: never let an empty or obviously wrong DEST reach `rm -rf`.
case "$DEST" in
  ""|"/"|"$HOME"|"$HOME/") echo "Refusing to install to '$DEST'." >&2; exit 1 ;;
esac
if [ "$(basename "$DEST")" != "stride-threat-model" ]; then
  echo "Refusing: target must end in 'stride-threat-model' (got '$DEST')." >&2; exit 1
fi
if [ ! -f "$SRC/SKILL.md" ]; then
  echo "Source does not look like the skill (no SKILL.md in $SRC)." >&2; exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST"
cp -pr "$SRC"/. "$DEST"/

grep -m1 -o 'SKILL VERSION: [^ ]*' "$DEST/SKILL.md" || true
echo "Installed stride-threat-model to $DEST"
echo "Files: $(find "$DEST" -type f | wc -l | tr -d ' ')"

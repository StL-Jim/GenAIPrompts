#!/usr/bin/env bash
# SKILL VERSION: v25-skill (2026-07-24b)
# tests/stride-threat-model/test-bash-invocation.sh
#
# Proves every skill script is invocable FROM BASH (Git Bash on Windows) using the
# canonical form documented in common.md rule S. This exists because a field run whose
# Claude Code harness drove bash could not run the skill at all: the phase files showed
# PowerShell-native call syntax and multi-line inline PowerShell blocks, neither of which
# works when pasted into bash. Run this whenever a script or a call site changes.
#
#   bash tests/stride-threat-model/test-bash-invocation.sh
#
# Exit 0 = every script ran from bash.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SK_NIX="$(cd "$HERE/../../skills/stride-threat-model/scripts" && pwd)"
# Windows-form path for -File (PowerShell wants a Windows path)
SK_WIN="$(cd "$SK_NIX" && pwd -W 2>/dev/null | sed 's|/|\\|g')"
[ -z "$SK_WIN" ] && SK_WIN="$SK_NIX"

WS_NIX="${TMPDIR:-/tmp}/stm-bashinv"
WS_WIN="$(cd "${TMPDIR:-/tmp}" && pwd -W 2>/dev/null | sed 's|/|\\|g')\\stm-bashinv"
PN='stm-bashinv'
PS="powershell.exe -NoProfile -ExecutionPolicy Bypass -File"

rm -rf "$WS_NIX"; mkdir -p "$WS_NIX/src" "$WS_NIX/terraform"
( cd "$WS_NIX" && git init -q \
  && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init ) >/dev/null 2>&1
printf 'BUCKET = os.environ["DATA_BUCKET"]\ndb="postgres://u@filings-prod:5432/m"\n' > "$WS_NIX/src/main.py"
printf 'resource "aws_s3_bucket" "d" { bucket = "filings-documents" }\n' > "$WS_NIX/terraform/s3.tf"
printf '# Readme\nUses SendGrid.\n' > "$WS_NIX/README.md"
mkdir -p "$WS_NIX/$PN-threat-model-20260101"
printf 'bucket\tfilings-documents\nbucket\tgone-legacy-bucket\n' > "$WS_NIX/$PN-threat-model-20260101/00-resources.txt"

pass=0; fail=0
check () { # name  expected-substring  command...
  local name="$1" want="$2"; shift 2
  local out; out="$("$@" 2>&1)"
  if printf '%s' "$out" | grep -q -- "$want"; then
    echo "  PASS  $name"; pass=$((pass+1))
  else
    echo "  FAIL  $name (expected to see: $want)"; printf '%s\n' "$out" | head -4; fail=$((fail+1))
  fi
}

check "init-workspace"    "init-workspace complete" $PS "$SK_WIN\\init-workspace.ps1"    -Workspace "$WS_WIN" -ProjectName "$PN"
check "manifest"          "Manifest file count"     $PS "$SK_WIN\\manifest.ps1"          -Workspace "$WS_WIN" -ProjectName "$PN"
check "partition"         "match: yes"              $PS "$SK_WIN\\partition-manifest.ps1" -Workspace "$WS_WIN" -ProjectName "$PN"
check "sweep"             "Sweep complete"          $PS "$SK_WIN\\sweep.ps1"             -Workspace "$WS_WIN" -ProjectName "$PN"

O="$WS_NIX/$PN-threat-model"
printf 'bucket\tfilings-documents\ntable\tnew-alerts\n' > "$O/00-resources.txt"
check "archive-compare"   "gone-legacy-bucket"      $PS "$SK_WIN\\archive-compare.ps1"   -Workspace "$WS_WIN" -ProjectName "$PN"

printf '# H\n' > "$O/02-header.md"; printf 'a\n' > "$O/02a-context.md"
printf 'b\n' > "$O/02b-threats.md"; printf 'c\n' > "$O/02c-assumptions.md"
check "consolidate"       "size-verified"           $PS "$SK_WIN\\consolidate.ps1"       -Workspace "$WS_WIN" -ProjectName "$PN"
# re-running must now fail loudly (header consumed) -- proves the missing-input guard
check "consolidate guard" "missing input file"      $PS "$SK_WIN\\consolidate.ps1"       -Workspace "$WS_WIN" -ProjectName "$PN"

mkdir -p "$O/diagrams"
printf '%s\n' '<mxfile host="app.diagrams.net" compressed="false"><diagram id="d" name="d"><mxGraphModel><root><mxCell id="0"/><mxCell id="1" parent="0"/></root></mxGraphModel></diagram></mxfile>' > "$O/diagrams/t.drawio"
check "validate-drawio"   "parsed OK"               $PS "$SK_WIN\\validate-drawio.ps1"   -Workspace "$WS_WIN" -ProjectName "$PN"

echo ""
echo "=== BASH INVOCATION: $pass passed, $fail failed ==="
rm -rf "$WS_NIX"
[ "$fail" -eq 0 ] || exit 1

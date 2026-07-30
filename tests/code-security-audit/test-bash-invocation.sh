#!/usr/bin/env bash
# SKILL VERSION: v1-skill (2026-07-30a)
# tests/code-security-audit/test-bash-invocation.sh
#
# Proves every skill script is invocable FROM BASH (Git Bash on Windows) using the
# canonical form documented in common.md rule S.
#
# This exists because of a field failure in the companion threat-model skill: a run whose
# Claude Code harness drove bash could not run the skill AT ALL. The phase files showed
# PowerShell-native call syntax, which does not work pasted into bash. The audit skill
# inherits rule S, so it inherits the need for this proof -- an agent on a bash harness is
# not a hypothetical, it is the configuration that already broke once.
#
#   bash tests/code-security-audit/test-bash-invocation.sh
#
# Exit 0 = every script ran from bash.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"

# ENVIRONMENT GUARD. This suite proves invocation from GIT BASH ON WINDOWS, which is what
# common.md rule S documents and what the harness that once failed in the field was using.
# It relies on `pwd -W` to convert POSIX paths to the Windows form powershell.exe -File
# needs. WSL bash and Linux bash do not support `pwd -W`: there the conversion silently
# yields a POSIX path, powershell.exe receives a workspace it cannot resolve, and every
# assertion below becomes meaningless -- passing or failing for reasons unrelated to the
# skill. Detect that and say so LOUDLY rather than reporting a result nobody should trust.
if ! (cd / && pwd -W) >/dev/null 2>&1; then
  echo "=================================================================="
  echo " SKIPPED: this suite requires Git Bash on Windows."
  echo " This shell does not support 'pwd -W' ($(uname -s)), so POSIX->Windows"
  echo " path conversion is unavailable and powershell.exe cannot be driven."
  echo " Nothing was verified. Run it from Git Bash to actually test rule S."
  echo "=================================================================="
  exit 0
fi

SK_NIX="$(cd "$HERE/../../skills/code-security-audit/scripts" && pwd)"
# PowerShell's -File wants a Windows path.
SK_WIN="$(cd "$SK_NIX" && pwd -W 2>/dev/null | sed 's|/|\\|g')"
[ -z "$SK_WIN" ] && SK_WIN="$SK_NIX"

WS_NIX="${TMPDIR:-/tmp}/csa-bashinv"
WS_WIN="$(cd "${TMPDIR:-/tmp}" && pwd -W 2>/dev/null | sed 's|/|\\|g')\\csa-bashinv"
PN='csa-bashinv'
PS="powershell.exe -NoProfile -ExecutionPolicy Bypass -File"

pass=0; fail=0
check() {  # check <name> <exit-code>
  if [ "$2" -eq 0 ]; then pass=$((pass+1)); echo "  PASS  $1"
  else fail=$((fail+1)); echo "  FAIL  $1 (exit $2)"; fi
}

# --- minimal fixture, built from bash on purpose ---------------------------
rm -rf "$WS_NIX"
mkdir -p "$WS_NIX/services/auth/src" "$WS_NIX/services/api/src" "$WS_NIX/shared/lib"
printf 'def login(u,p):\n    return u\n'      > "$WS_NIX/services/auth/src/login.py"
printf 'def handler(req):\n    return 200\n'  > "$WS_NIX/services/api/src/handler.py"
printf 'def query(sql):\n    return sql\n'    > "$WS_NIX/shared/lib/db.py"
printf '# fixture\n'                          > "$WS_NIX/README.md"
( cd "$WS_NIX" && git init -q \
  && git -c user.email=t@t -c user.name=t add -A \
  && git -c user.email=t@t -c user.name=t commit -q -m init ) >/dev/null 2>&1

echo "=== bash invocation of every skill script (common.md rule S) ==="

$PS "$SK_WIN\\init-workspace.ps1" -Workspace "$WS_WIN" -ProjectName "$PN" -Mode STANDALONE >/dev/null 2>&1
check "init-workspace.ps1 runs from bash" $?

$PS "$SK_WIN\\manifest.ps1" -Workspace "$WS_WIN" -ProjectName "$PN" >/dev/null 2>&1
check "manifest.ps1 runs from bash" $?

$PS "$SK_WIN\\partition-plan.ps1" -Workspace "$WS_WIN" -ProjectName "$PN" >/dev/null 2>&1
check "partition-plan.ps1 runs from bash" $?

# merge-findings needs worker output; without it the script must FAIL CLOSED rather than
# emit an empty registry.
#
# Establish the precondition explicitly rather than trusting the rm -rf at the top of this
# script. That rm races a PowerShell process that has only just exited and may still hold
# handles under Windows; when it loses, worker directories from the PREVIOUS run survive,
# merge-findings correctly succeeds, and this negative test reports a spurious failure.
# A test whose result depends on whether a delete won a race is worse than no test.
rm -rf "$WS_NIX/audit_state/workers"
mkdir -p "$WS_NIX/audit_state/workers"
if [ -n "$(ls -A "$WS_NIX/audit_state/workers" 2>/dev/null)" ]; then
  fail=$((fail+1)); echo "  FAIL  could not establish empty workers/ precondition"
else
  $PS "$SK_WIN\\merge-findings.ps1" -Workspace "$WS_WIN" -ProjectName "$PN" >/dev/null 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then pass=$((pass+1)); echo "  PASS  merge-findings.ps1 fails closed with no worker output"
  else fail=$((fail+1)); echo "  FAIL  merge-findings.ps1 should not succeed with no worker output"; fi
fi

# Now give it workers and confirm it succeeds when invoked from bash.
for p in services-auth services-api shared; do
  mkdir -p "$WS_NIX/audit_state/workers/$p"
  printf 'id: F-%03d\npid: %s\nsrc: %s/x.py:1-2\nclass: Confirmed\nsev: High\n\n' "$RANDOM" "$p" "$p" \
    > "$WS_NIX/audit_state/workers/$p/findings.md"
done
# Disjoint, deterministic ids (the RANDOM above could collide; overwrite with fixed blocks).
i=1
for p in services-auth services-api shared; do
  printf 'id: F-%03d\npid: %s\nsrc: %s/x.py:1-2\nclass: Confirmed\nsev: High\n\n' "$i" "$p" "$p" \
    > "$WS_NIX/audit_state/workers/$p/findings.md"
  i=$((i+20))
done
{
  echo '# Partition Status'
  echo ''
  echo '| partition_id | files | status |'
  echo '|---|---|---|'
  for p in services-auth services-api shared; do echo "| $p | 1 | done |"; done
} > "$WS_NIX/audit_state/partition_status.md"

$PS "$SK_WIN\\merge-findings.ps1" -Workspace "$WS_WIN" -ProjectName "$PN" >/dev/null 2>&1
check "merge-findings.ps1 runs from bash with worker output" $?

# The carve verifier is a build-time tool but is run the same way from CI or a bash shell.
CARVE_WIN="$(cd "$HERE" && pwd -W 2>/dev/null | sed 's|/|\\|g')"
[ -z "$CARVE_WIN" ] && CARVE_WIN="$HERE"
$PS "$CARVE_WIN\\carve.ps1" >/dev/null 2>&1
check "carve.ps1 runs from bash" $?

# --- guard: no phase file tells an agent to run a bare .ps1 path -----------
# A phase file showing `& '<SKILL_DIR>\scripts\x.ps1'` with no powershell.exe form is the
# exact shape that broke the bash field run. Rule S requires both forms be available.
REFS="$HERE/../../skills/code-security-audit/references"
if grep -rlE "^\s*&\s*'[^']*\.ps1'" "$REFS" 2>/dev/null | grep -v 'common.md' | grep -q .; then
  fail=$((fail+1))
  echo "  FAIL  a reference file shows PowerShell-only script invocation:"
  grep -rlE "^\s*&\s*'[^']*\.ps1'" "$REFS" 2>/dev/null | grep -v 'common.md' | sed 's/^/          /'
else
  pass=$((pass+1))
  echo "  PASS  no reference file shows PowerShell-only script invocation"
fi

echo ""
echo "PASS: $pass   FAIL: $fail"
[ "$fail" -eq 0 ] || exit 1
echo "ALL BASH INVOCATION TESTS PASSED"
exit 0

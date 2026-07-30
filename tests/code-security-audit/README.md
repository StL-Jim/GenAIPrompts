# tests/code-security-audit

Regression tests for the `code-security-audit` skill.

## Running them

```powershell
pwsh -File tests/code-security-audit/test-scripts.ps1
```
```bash
bash tests/code-security-audit/test-bash-invocation.sh
pwsh -File tests/code-security-audit/carve.ps1
```

All three exit 0 on success. Run all three after any change to the skill.

## What each covers

### `carve.ps1` -- methodology fidelity

The skill's methodology is not transcribed from `code-security-audit.md`, it is EXTRACTED
from it by line range. This script does the extraction (`-Emit`) and verifies it (default,
read-only).

Verbatim fidelity is the acceptance criterion for the whole conversion, so this is the
test that matters most. Two independent checks:

- the sha256 in each carve marker vs. a fresh computation from source -- catches the
  source prompt moving underneath the skill
- the text between the markers vs. freshly carved source -- catches a reference file
  being hand-edited

It also reports SOURCE COVERAGE: every one of the source prompt's 1243 lines must be
accounted for as CARVED, ABSORBED (rewritten into SKILL.md because it describes
orchestration rather than analysis) or FILLER (separators and banners, which are asserted
to actually be separators). An unaccounted line means methodology may have been dropped,
and fails the run.

The only permitted deviation is declared as a transform with an asserted minimum match
count: `F-YYYYMMDD-NNN` -> `F-NNN`. If that transform ever stops matching, the run fails
rather than reporting success while changing nothing.

### `test-scripts.ps1` -- deterministic script behaviour

Builds a fixture and runs init/manifest/partition/merge in BOTH coordination modes.

Both modes are run deliberately. STANDALONE is a first-class path, but it is almost never
the mode used in the field, so without a test that exercises it on every run it rots
silently and nobody notices until it is needed.

Asserted, among others:

- the cross-run log `security_architecture_audit.md` at the workspace ROOT survives init
  untouched -- clobbering it destroys the history of every prior audit, unrecoverably
- a prior `audit_state-YYYYMMDD` run is detected by PRESENCE and its contents never read
- `STATE.md` sets Phase 6 `not_applicable` in STANDALONE, so resume never waits on a phase
  that will never run
- init is idempotent: a second run does not overwrite an existing `STATE.md`, which would
  silently reset a resume
- the manifest excludes `node_modules`, `vendor`, `audit_state*`, `.git`, the root
  cross-run log, and (in COORDINATED) the threat-model directory
- partitioning stays within the cap of 5, every manifest file lands in exactly one
  partition, and none lands in two
- `merge-findings.ps1` FAILS CLOSED on duplicate finding ids, on a severity outside
  Critical/High, and on a partition not marked done -- then recovers to green once the
  injected fault is removed, so a pass proves the fault caused the failure

Line endings are deliberately NOT asserted. Git's `core.autocrlf` rewrites them on
checkout, so asserting on them produces a suite that fails on a clean Windows clone.
NUL bytes and non-ASCII content ARE asserted.

### `test-bash-invocation.sh` -- rule S

Proves every script is invocable from bash (Git Bash on Windows) using the canonical
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File` form.

This exists because of a real failure in the companion threat-model skill: a run whose
harness drove bash could not execute the skill at all. It also greps the reference files
for PowerShell-only invocation syntax, which is the shape that caused it.

### `make-fixture.ps1` -- the test repository

```powershell
pwsh -File tests/code-security-audit/make-fixture.ps1 -Path <dir> [-Mode COORDINATED] [-Force]
```

A monorepo with MORE service roots than the partition cap, so the cap and the `assorted`
merge path are exercised rather than skipped. Includes the things that must be excluded
(`node_modules`, `vendor`), the things that must survive (the root cross-run log), the
things that must be detected but not read (a prior `audit_state-YYYYMMDD`), and a real git
repo so the `.git/info/exclude` path actually runs.

In COORDINATED mode it also writes a threat model with a main threat table and an Excluded
Threats Ledger carrying the reason values the cross-reference procedure branches on
(`Code-level`, `Attested-mitigated (unverified)`, `Fully mitigated`, `Unverified`).

## What these tests do NOT cover

They exercise the DETERMINISTIC layer: scripts, artifacts, exclusions, reconciliation,
fail-closed paths, and methodology fidelity.

They do NOT exercise agent behaviour -- subagent dispatch, parallel worker execution, the
gates, or whether the carved methodology actually produces good findings when a model
follows it. That requires a real run against a real codebase.

Until such a run has happened, this skill is BUILT, not VALIDATED. A green suite here
means the machinery is sound, not that the audit works.

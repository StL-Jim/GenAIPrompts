# SKILL VERSION: v2-skill (2026-08-14a)
# Changelog -- code-security-audit skill

SKILL.md has referenced this file since v1 and it did not exist. Created when the version stamps
were reconciled, because a dangling reference in the one document that tells you what version you
are running is the same class of problem as a stale stamp.

Every file in this skill carries the same `SKILL VERSION:` stamp, and the test suite fails if any
two disagree. The stamp printed at session start is the one in `SKILL.md`.

---

## v2-skill (2026-08-14a)

Architecture change, not a patch release. Everything below came out of the first field runs
against a real 1,479-file application.

### Partitioning replaced: one ordered bucket, cut into slices

Partitions were built one-per-service-root with a root treated as atomic, so a 5,377 KB `src`
tree went to a single worker that could hold about a seventh of it. The machinery grown to cope
-- read floor, byte budget, recursive splitter, coverage arithmetic, SPLIT REQUIRED, root clamp
-- all existed to make that shape survive.

Now every auditable file goes into one bucket ordered by functional area (service root + first
subdirectory), cut into subagent-sized slices, dispatched `-MaxParallel` at a time in waves.

- **Order is the selection.** Nothing is excluded, only earlier or later. Stopping after two
  waves means the two most valuable waves were done.
- **Slice size is an estimate, not a contract.** A worker that runs short reports where it
  stopped; the remainder is re-sliced into a later wave.

### Workers can report running short

The carved banner said `PHASE 3A COMPLETE` unconditionally. A worker out of room could only lie
or fail silently, and both read downstream as "looked and found nothing" -- the most dangerous
output this tool can produce. Workers now write `unreviewed.txt` and print `INCOMPLETE`; GATE 2
reports `NEVER REVIEWED: N file(s)` beside the findings count.

### Orchestrator context discipline

A field run exhausted the orchestrator mid-audit. Worker summaries are now capped to the banner,
`readplan.ps1 -Quiet` cuts plan output 70% at 22 slices, and a wave boundary is documented as a
clean session boundary with `STATE.md` as the handoff.

### Selection accuracy

- `.sql` files were floored for containing `SELECT ... FROM` -- 378 of 380 on the real repo.
  File-type-aware sink patterns; a routine `GRANT EXECUTE ... TO AppRole` is deployment, not a
  defect. 378 -> 25.
- `.cshtml` narrowed to unescaped-output patterns.
- `Get-SinkReason` attributes each floored file to the rule that floored it.
- Files over `-MaxFileKB` are named: slicing divides between files, never within one.

### Correctness fixes

- **The audit was auditing itself.** `audit_state` was excluded at top level only, and the threat
  model only when named exactly `<project>-threat-model`. A worker reading a prior
  `findings_registry.md` reports every issue the last run found, attributed to a file that is not
  application code.
- The file walk descended into `.git` before filtering it out.
- `Get-SinkReason` opened each file once per pattern group; now one read, memoised.
- GATE 1 interrogated the owner about production build configuration. It now resolves what the
  repo can answer, records what it cannot as an assumption, and raises the rest as findings.
- COORDINATED mode treated the threat model's inventory as authoritative in the phase that
  produces the risk ranking. Both inventories are now built independently and reconciled.
- Judge: added `uphold-corrected`; a basis neither side argued is the judge's own claim and must
  meet the same evidence bar.
- GATE 2: rebuilt as a resumable walk with `accepted`, a stop option, inline option meanings, and
  permission to ask questions and get re-read evidence.

## v1-skill (2026-07-29 .. 2026-07-31)

Initial conversion of `code-security-audit.md` into a multi-agent skill: carve-based methodology
extraction with build-time verification, parallel workers with disjoint finding-ID blocks,
critic and judge passes, precondition test, excluded-candidate ledger, and the deliverable
completeness check.

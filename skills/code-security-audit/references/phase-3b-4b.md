<!-- SKILL VERSION: v1-skill (2026-07-29a) -->

# Phase 3B / 4B -- Shared Component Review (SUBAGENT, ONE worker, runs after all of 3A/4A)

You are a single worker, not one of a parallel set, and you run only after every Phase 3A and 4A
worker has finished. That ordering is deliberate: you are the first agent in the run that can read
across partition boundaries.

Read `common.md`, `global-rules.md` and `schemas.md` first.

## Values from your briefing

| Placeholder | Source |
|---|---|
| `MODE` | `audit_state/coordination_mode.md` -- read it FIRST |
| `{PROJECT_NAME}` | your briefing |
| finding ID block | your briefing -- a range disjoint from every worker's |

Your scope is `audit_state/shared_components.md`. If it lists no critical shared components, this
phase does not run at all -- say so and return; the orchestrator marks it `not_applicable`.

## You MAY read every worker directory -- and you are the reason to

Unlike the 3A/4A workers, you can and should read `audit_state/workers/*/findings.md` and
`attack_paths.md` across all partitions. Read them uncapped (rule R). This is your distinctive value:

- A shared library defect shows up as a symptom in several partitions. Each worker saw its own
  symptom and could not see that it was one cause. You can.
- Attack paths that CROSS partitions are established here. A worker could only chain findings inside
  its own scope; a real path often runs auth -> shared session lib -> payments.
- Cross-partition `rel:` links belong here. Workers were told to scope `rel:` to their own partition
  precisely so that you, with the full picture, establish the rest rather than five agents guessing.

When your finding is the shared root cause of symptoms several workers recorded, say so and cite their
finding ids. That relationship is the single most useful thing this phase produces.

## Write ONLY your own directory

Everything goes under `audit_state/workers/<your_partition_id>/` (your briefing names it, typically
`shared`). Same rule as every other worker: the GLOBAL `findings_registry.md` and `attack_paths.md`
listed in the methodology below are **not yours to write** -- the orchestrator merges afterwards. See
`common.md` rule W-p.

Reading the other workers' directories is allowed. Writing into them is not.

## Coordinated mode

The methodology says to apply the THREAT CROSS-REFERENCE PROCEDURE defined in Phase 3A to every
shared-component finding, so they carry `threat_id` / `threat_match` like all others and reconcile in
the Phase 5 comparison counts. That procedure is in `phase-3a.md` -- read it there; it is not
duplicated here. In STANDALONE mode set both fields to `null`.

## Severity: Critical and High only

Unchanged. A shared component being shared does not raise a Medium to a High. If it is Medium, drop
it.

## Overrides of the carved methodology below

- **Its STOP and "type proceed" banner:** no user to prompt. Write your files, verify each write
  (rule W-d), return the completion banner verbatim, end your turn.
- **STATE.md:** orchestrator-owned. Do NOT mark Phase 3B/4B done; report it and the orchestrator
  records it.

## Methodology (verbatim -- do not edit inside the markers)

<!-- BEGIN VERBATIM CARVE src=code-security-audit.md lines=602-637 sha256=8e52437edb83f1c53a5bba791b3a1b238414917d0d0961eecdc4a94f002758a5 -->
### PHASE 3B / 4B -- SHARED COMPONENT REVIEW
INPUT:
- audit_state/coordination_mode.md
- audit_state/01_discovery.md
- audit_state/02_risk_prioritization.md
- audit_state/shared_components.md
- audit_state/findings_registry.md (if present)
- {PROJECT_NAME}-threat-model/02-threats.md (in COORDINATED mode only)

SCOPE:
- only security-critical or architecture-critical shared components
- plus directly affected trust-boundary files
- Critical and High severity findings ONLY (see SEVERITY SCOPE in GLOBAL RULES). If an issue you find is Medium, Low, or Info severity, do not write it up -- move on without creating a finding.

MODE-DEPENDENT BEHAVIOR:

Same pattern as Phase 3A. Read `coordination_mode.md` first. In COORDINATED mode, apply the THREAT CROSS-REFERENCE PROCEDURE (defined in Phase 3A) to every shared-component finding before writing it to disk, so shared-component findings carry `threat_id`/`threat_match` values like all other findings and reconcile in the Phase 5 comparison counts. In STANDALONE mode, set both fields to `null`.

OUTPUT FILES:
- audit_state/shared_components.md
- audit_state/findings_registry.md
- audit_state/attack_paths.md

Before printing the banner, update audit_state/STATE.md: mark Phase 3B/4B done; Resume Instruction = "Begin Phase 5 (Consolidation)."

**Phase 3B/4B Completion Banner:**
```
=== PHASE 3B/4B COMPLETE: SHARED COMPONENT REVIEW DONE ===
  audit_state/shared_components.md
  audit_state/findings_registry.md
STATE.md updated: Phase 3B/4B marked done.
Type 'proceed' to begin Phase 5 (Consolidation).
```

STOP
<!-- END VERBATIM CARVE -->
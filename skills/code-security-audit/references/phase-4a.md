<!-- SKILL VERSION: v1-skill (2026-07-29a) -->

# Phase 4A -- Worker Architecture + Functional Review (SUBAGENT, one per partition, RUN IN PARALLEL)

You are one of up to five workers running AT THE SAME TIME as your siblings, and you run AFTER the
Phase 3A worker for your partition has finished.

Read `common.md`, `global-rules.md` and `schemas.md` first.

## Values from your briefing

| Placeholder | Source |
|---|---|
| `<partition_id>` | your briefing -- YOUR partition, and only yours |
| `{PROJECT_NAME}` | your briefing |
| `MODE` | `audit_state/coordination_mode.md` -- read it FIRST |
| finding ID block | your briefing -- a range DISJOINT from your Phase 3A predecessor's |

Your file list is `audit_state/partitions/<partition_id>.txt`. Read it uncapped (rule R).

## Read your partition's Phase 3A output first

`audit_state/workers/<partition_id>/security_review.md` and `findings.md` already exist for your
partition. Read them. Architecture findings that restate a security finding already recorded there are
duplicates, and an architecture review that ignores what the security pass found will produce them.

## ARCH findings do not need an OWASP category

Architecture findings frequently have no meaningful OWASP mapping -- coupling, resilience, operational
fragility. Set `cat: ARCH` and use a descriptive `sub` (for example `Tight Coupling`,
`Missing Bulkhead`, `Single Point of Failure`). Do not force-fit an OWASP category onto a
non-security architecture finding just to fill the field.

Severity scope still binds: Critical and High only.

## Write ONLY your own directory, and do not clobber your predecessor

Everything goes under `audit_state/workers/<partition_id>/`:

- `architecture_review.md` -- new, yours
- `findings.md` -- **APPEND to the existing file.** Phase 3A wrote findings here. Read before write.
  Overwriting it destroys your partition's security findings.
- `attack_paths.md` -- append, same reasoning
- `evidence_index.md` -- append; the methodology is explicit that Phase 3A's entries must survive

The methodology lists the GLOBAL `audit_state/findings_registry.md` and `audit_state/attack_paths.md`
among this phase's outputs. **Do not write them** -- see `common.md` rule W-p. Your siblings are
running now, and the orchestrator merges afterwards.

## You cannot see other partitions' findings

Same as Phase 3A: the global registry does not exist yet. Scope `rel:` to your own partition. Phase
3B/4B and Phase 5 establish cross-partition relationships.

## Overrides of the carved methodology below

- **Its STOP and "type proceed" banner:** no user to prompt. Write your files, verify each write
  (rule W-d), return the completion banner verbatim, end your turn.
- **STATE.md and partition_status.md:** orchestrator-owned. Do NOT mark your partition `done`; report
  it and the orchestrator records it.

## Methodology (verbatim -- do not edit inside the markers)

<!-- BEGIN VERBATIM CARVE src=code-security-audit.md lines=543-599 sha256=75bd885c893823b0f291be8f91a58b744c1af9129ce2ffff8b5e92abaffa3c7f -->
### PHASE 4A -- WORKER ARCHITECTURE + FUNCTIONAL REVIEW
INPUT:
- audit_state/coordination_mode.md
- audit_state/01_discovery.md
- audit_state/02_risk_prioritization.md
- audit_state/partition_plan.md
- audit_state/shared_components.md
- audit_state/findings_registry.md
- audit_state/workers/<partition_id>/security_review.md (if present)
- {PROJECT_NAME}-threat-model/02-threats.md (in COORDINATED mode only)

SCOPE:
- one partition only
- plus directly relevant shared or trust-boundary files
- Critical and High severity findings ONLY (see SEVERITY SCOPE in GLOBAL RULES). If an issue you find is Medium, Low, or Info severity, do not write it up -- move on without creating a finding.

MODE-DEPENDENT BEHAVIOR:

Same pattern as Phase 3A. In COORDINATED mode, apply the threat cross-reference procedure (from Phase 3A) to every architecture finding before writing it to disk. Architecture findings can match threat model threats too -- for example, a missing-bulkhead pattern finding may correspond to a threat about cascading failure. Same `confirms` / `partial` / `unanticipated` semantics apply.

ANALYZE:
- coupling/cohesion
- dependency direction
- boundary violations
- shared state risks
- error handling
- resilience/failure modes
- race conditions
- edge cases
- operational fragility

OUTPUT FILES:
- audit_state/workers/<partition_id>/architecture_review.md
- audit_state/workers/<partition_id>/findings.md
- audit_state/workers/<partition_id>/attack_paths.md
- audit_state/workers/<partition_id>/evidence_index.md (updated with architecture evidence -- READ before WRITE; do not overwrite the Phase 3A entries)
- audit_state/findings_registry.md
- audit_state/attack_paths.md
- audit_state/partition_status.md (this partition set to done)

Before printing the banner, perform both state updates:
1. Update audit_state/partition_status.md: set partition '<partition_id>' to done.
2. Update audit_state/STATE.md: mark partition '<partition_id>' done under Phase 4A. Before writing Resume Instruction, check the Phase 4A per-partition list in STATE.md (or partition_plan.md) for ANY partition still pending or in_progress -- never assume the partition just completed was the last one without checking this list. If at least one partition still needs Phase 4A, Resume Instruction = "Begin Phase 4A for partition '<next_pending_partition_id>'." Only if EVERY partition shows Phase 4A done should Resume Instruction = "Begin Phase 3B/4B (Shared Component Review)." (if shared_components.md lists critical components) or "Begin Phase 5 (Consolidation)." (otherwise).

**Phase 4A Completion Banner:**
```
=== PHASE 4A COMPLETE: ARCHITECTURE REVIEW DONE FOR PARTITION '<partition_id>' ===
  audit_state/workers/<partition_id>/architecture_review.md
  audit_state/workers/<partition_id>/findings.md
  audit_state/findings_registry.md
STATE.md and partition_status.md updated: partition '<partition_id>' recorded as done.
Resume Instruction set to: <the instruction written in the state update above>
Type 'proceed' to continue.
```

STOP
<!-- END VERBATIM CARVE -->
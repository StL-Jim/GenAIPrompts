<!-- SKILL VERSION: v2-skill (2026-08-14a) -->

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

**You are NOT given a finding ID block, because you do not produce findings.** If your briefing
contains one, it is stale -- ignore it and say so in your summary.

Your file list is `audit_state/partitions/<partition_id>.txt`. Read it uncapped (rule R).

## You produce OBSERVATIONS, not findings

This is the change that matters most in this file, and the carved text below now says it too.

Architecture output is a different product from security output. It has a different evidence
standard, a different audience, and a different remedy -- refactor rather than patch. Forcing it
onto the security severity scale, whose two anchors are "complete system compromise, RCE" and
"privilege escalation, auth bypass", produced inflated severities rather than information: the only
way to keep a real observation about coupling was to call it High, and it then competed with SQL
injection in one ranked list. A field run emitted 53 findings of which only 22 were security
issues, largely for this reason.

So:

- Write your observations to `audit_state/workers/<partition_id>/architecture_review.md`. That is
  their SOLE home.
- No finding ID. No `sev`. No `score`. No `cat: ARCH`. No entry in `findings.md`, and none in the
  global `findings_registry.md`.
- Record what it is, where it is, why it matters operationally, and the evidence. Order them by
  consequence in your own prose.
- The Critical/High floor does not apply to you. It has no meaning for coupling or operational
  fragility, and applying it is what caused the inflation.

Phase 5 gives these their own section, so nothing you write here is discarded -- it is delivered
separately from the security findings instead of competing with them.

## If you find a real code defect, that IS a security finding

Reviewing architecture sometimes turns up an actual exploitable defect. When it does, it is a
Phase 3A finding, not an observation. Record it in
`audit_state/workers/<partition_id>/findings.md` with everything Phase 3A requires -- bare field
lines, quoted evidence, and an id. Take the id from the block your PARTITION'S Phase 3A worker was
given, continuing after its highest used id, and say in your summary which ids you used so the
orchestrator can update the allocation table.

This should be uncommon. If most of your output is landing in `findings.md`, you are doing Phase 3A
again rather than Phase 4A.

## Read your partition's Phase 3A output first

`audit_state/workers/<partition_id>/security_review.md` and `findings.md` already exist for your
partition. Read them. An observation that restates a security finding already recorded there is a
duplicate, and a review that ignores what the security pass found will produce them.

## Write ONLY your own directory, and do not clobber your predecessor

Under `audit_state/workers/<partition_id>/`:

- `architecture_review.md` -- new, yours, and the only file you normally write
- `evidence_index.md` -- **APPEND.** Phase 3A wrote entries here; the methodology is explicit that
  they must survive. READ before WRITE.
- `findings.md` -- touch ONLY for the code-defect case above, and then APPEND. Phase 3A's findings
  are in this file and overwriting it destroys them.

Rule W names the Write tool first and says it overwrites. For these two files that is the wrong
tool: read the existing content, add yours, write the whole thing back -- or use Edit. The merge's
size check compares the merged result against its inputs, so it CANNOT detect that an input was
halved before merging.

The methodology no longer lists the global `findings_registry.md` or `attack_paths.md` as your
outputs. Do not write them regardless (`common.md` rule W-p).

## Overrides of the carved methodology below

- **Its STOP and "type proceed" banner:** no user to prompt. Write your files, verify each write
  (rule W-d), return the completion banner verbatim, end your turn.
- **STATE.md and partition_status.md:** orchestrator-owned. Do NOT mark your partition `done`;
  report it and the orchestrator records it.
- **COORDINATED mode:** note in prose where an observation lines up with a threat in the model. Do
  NOT populate `threat_id` or `threat_match` -- those are finding fields and you produce no
  findings.
## Methodology (verbatim -- do not edit inside the markers)

<!-- BEGIN VERBATIM CARVE src=code-security-audit.md lines=559-614 sha256=30a16a0190330ce192b56801ca2730526e364084985dc69690b9495a5e5ef44f -->
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
- This phase does NOT produce security findings. It produces ARCHITECTURE OBSERVATIONS, and they belong in `architecture_review.md` only. They get no finding ID, no severity, no risk score, and no entry in `findings.md` or `findings_registry.md`.
- The Critical/High severity floor does not apply here, because it does not mean anything here. Coupling, resilience and operational fragility do not sit on a scale whose two anchors are "complete system compromise, data breach, RCE" and "significant data exposure, privilege escalation, auth bypass". Forcing them onto it yields inflated severities rather than information: the only way to keep a real architecture observation was to call it High, and it then competed with SQL injection in the same ranked list.
- Record each observation with what it is, where it is, why it matters operationally, and the evidence for it. Order them by consequence in your own words. Do not borrow the security severity vocabulary to do that.
- If, while reviewing architecture, you find an actual exploitable CODE DEFECT, that is a Phase 3A finding. Record it as one, in `findings.md`, with everything Phase 3A requires.

MODE-DEPENDENT BEHAVIOR:

In COORDINATED mode, note in `architecture_review.md` where an observation corresponds to a threat in the model -- a missing-bulkhead pattern may correspond to a threat about cascading failure, and saying so is useful to a reader. Do NOT run the threat cross-reference procedure and do NOT populate `threat_id` or `threat_match`: those are finding fields, and this phase produces no findings.

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
- audit_state/workers/<partition_id>/architecture_review.md (the SOLE home for this phase's observations)
- audit_state/workers/<partition_id>/evidence_index.md (updated with architecture evidence -- READ before WRITE; do not overwrite the Phase 3A entries)
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
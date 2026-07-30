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
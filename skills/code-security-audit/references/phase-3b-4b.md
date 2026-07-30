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
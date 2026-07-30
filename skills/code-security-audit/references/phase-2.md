<!-- BEGIN VERBATIM CARVE src=code-security-audit.md lines=384-422 sha256=58ae393614b7174ad252615333b22f63501417e89f00d01c1210ac68ff8498d8 -->
### PHASE 2 -- GLOBAL RISK PRIORITIZATION
INPUT:
- audit_state/01_discovery.md
- audit_state/resource_inventory.md
- audit_state/partition_plan.md
- audit_state/shared_components.md

ACTIONS:
- Rank:
  - services/partitions by exposure, blast radius, and likely defect density
  - components within top partitions
- Identify:
  - highest-risk areas
  - exact files and interfaces for deep inspection
- In COORDINATED mode, read the `Code-level` and `Attested-mitigated (unverified)` rows of the threat model's Excluded Threats Ledger: both are seeded leads routed to this audit. `Code-level` rows are predicted defects -- the files and components they name are automatically top-tier inspection targets. `Attested-mitigated (unverified)` rows each name a user-attested control and the specific check that would verify it: perform that check. If the control is present and effective, record it in the comparison notes (attestation verified). If it is absent or ineffective, raise a finding -- it will match the row as a contradicted attestation, one of the most important results the coordinated toolchain can produce.
- Account for every file in the partition (see FILE COVERAGE ACCOUNTING below) -- ranking guides inspection depth in Phase 3A/4A, it must never cause a file to be silently dropped from consideration.

FILE COVERAGE ACCOUNTING:

Tiering exists to focus depth of review, not to shrink the set of files Phase 3A/4A will look at. Every file belonging to the partition (per `resource_inventory.md` / `partition_plan.md`) must be accounted for somewhere in `02_risk_prioritization.md` -- either in a ranked tier with rationale, or in a single rolled-up lowest-priority bucket (e.g., "Tier N (pattern-scan only): <count> files -- <category description, such as 'test files, generated code, simple utility modules'>"). The rolled-up bucket does not need per-file rationale; a category description and a count are sufficient -- this keeps the accounting cheap regardless of partition size.

Before writing the completion banner, compute `tier1 + tier2 + ... + tierN == total files in partition`. Report this count in the banner (see below) so a coverage gap is visible immediately rather than discovered later by re-reading the file. This is a visibility check, not a hard gate -- if the count is short, report it honestly and proceed; do not loop re-deriving the table to force an exact match, since that costs tokens without necessarily adding review value.

OUTPUT:
- audit_state/02_risk_prioritization.md

Before printing the banner, update audit_state/STATE.md: mark Phase 2 done; Resume Instruction = "Begin Phase 3A (Worker Security Review) for partition '<first_partition_id>'."

**Phase 2 Completion Banner:**
```
=== PHASE 2 COMPLETE: RISK PRIORITIZATION DONE ===
  audit_state/02_risk_prioritization.md
  Tier coverage: <N> of <total> partition files accounted for
STATE.md updated: Phase 2 marked done.
Type 'proceed' to begin Phase 3A for partition '<first_partition_id>'.
```

STOP
<!-- END VERBATIM CARVE -->
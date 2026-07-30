<!-- SKILL VERSION: v1-skill (2026-07-29a) -->

# Phase 2 -- Global Risk Prioritization (ORCHESTRATOR, not a subagent)

You run this yourself. It is small, it produces no findings, and it feeds GATE 1 -- which is a
conversation with the user, and subagents cannot have one.

## Why this phase exists before GATE 1

Phase 1 already wrote `partition_plan.md`. This phase ranks partitions by exposure, blast radius and
likely defect density -- and that ranking is what makes the partition plan REVIEWABLE. A bare table
of file counts is close to unjudgeable; the same table alongside "auth ranked highest exposure" is a
question a person can actually answer. Produce the ranking first, then open GATE 1 with both.

You MAY revise `partition_plan.md` here if the ranking reveals a better grouping. If you do, keep
`audit_state/partitions/<partition_id>.txt` and `partition_status.md` consistent with the revision,
and re-state the reconciliation count.

## GATE 1 -- after this phase, before any worker is dispatched

Present to the user, in this order:

1. The partition table: id, file count, percentage, service roots.
2. The risk ranking from this phase, in plain language -- what is most exposed and why.
3. Anything `partition-plan.ps1` warned about. In particular, if the `assorted` partition outgrew the
   largest coherent one, say so plainly: the repo's shape does not fit a 5-partition cap and the
   grouping may need to be different.
4. Shared-component candidates, flagged as name-convention leads rather than conclusions.

Then ask whether the partitioning is right, and wait. Do not dispatch workers until the user answers.

A wrong partition wastes every worker downstream and costs almost nothing to fix at this point. That
asymmetry is the entire reason this gate exists.

### What to ask, and what not to

Ask the user about SCOPE and REALITY -- what he alone knows:

- Is any partition covering something decommissioned, or not actually deployed?
- Is anything grouped together that should be separate, or split that belongs together?
- Are the shared-component candidates genuinely shared?
- Is any of this not internet-facing, or otherwise less exposed than the ranking assumes?

Do NOT ask him to validate the risk-scoring arithmetic, confirm your OWASP mappings, or certify any
code-level technical judgement. He is not the source for those, and asking invites an approval that
carries no information.

Take his answers at face value. He is describing a system he operates and you do not. If an answer
contradicts what you read in the code, say so plainly once, with the evidence, and let him decide --
that is a discrepancy worth surfacing, not an attestation to interrogate. Verification pressure
belongs on subagent OUTPUT, never on the user.

## Overrides of the carved methodology below

- **Its STOP and "type proceed" banner:** you are the orchestrator, so a stop here is real -- but the
  stop is GATE 1 as described above, not a literal wait for the word "proceed."
- **STATE.md:** you own it. Update it as the methodology instructs. This is the one phase where that
  instruction applies to you directly.
- **The tier-coverage count** in the completion banner is a visibility check, not a hard gate. The
  carved text is explicit that a short count should be reported honestly rather than looped over --
  respect that. Do not re-derive the table to force an exact match.

## Methodology (verbatim -- do not edit inside the markers)

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
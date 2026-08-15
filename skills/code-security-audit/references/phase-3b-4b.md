<!-- SKILL VERSION: v2-skill (2026-08-14a) -->

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

You have TWO scopes, and the second is now the more important one:

1. `audit_state/shared_components.md` -- shared code reviewed as one thing rather than N symptoms.
2. **Every `audit_state/workers/*/cross_partition_leads.md`** -- questions the 3A workers could
   establish only half of, because the other half was in a different slice.

**This phase runs if EITHER has content.** It is skipped only when there are no critical shared
components AND no cross-partition leads. Skipping it while leads are outstanding discards the one
category of vulnerability the slicing method is structurally blind to.

## Resolving cross-partition leads is your first job, before shared components

A field run lost a real vulnerability exactly here. A 3A worker found code building SQL from a
parameter, could not determine whether that parameter was attacker-controlled because the caller
lived in another slice, correctly declined to file an ungrounded finding, and returned no findings
at all. Every step was right and the audit still missed it.

You are the only agent that can close that gap: you read across partitions.

For each lead, in order:

1. Read the line. It names what was established, the question, and what would answer it.
2. **Go and read that other code.** This is the whole point of your phase -- you are not
   re-reviewing a partition, you are answering ONE question with the file the asker could not open.
3. Resolve it to exactly one of:
   - **Confirmed** -- write it as a finding in your own ID block. Cite the originating partition
     and the file on BOTH sides; the attack path crosses a boundary and the write-up must show it.
   - **Refuted** -- the input is not attacker-controlled, or the sink is parameterised after all.
     Record it in `excluded_candidates.md` with the reason and what you read to establish it.
   - **Unresolved** -- you could not settle it either. Say so explicitly and carry it into your
     output with what is still missing. Never leave a lead silently unanswered.
4. Every lead ends in one of those three states. A lead you did not look at is the original failure
   happening a second time, with less excuse.

A confirmed cross-partition finding is among the most valuable things this audit produces: it is
precisely what a single-file scanner and a per-slice reviewer both structurally cannot see.

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

## Write ONLY your own directory -- and these exact filenames

Your briefing names your partition id (typically `shared`). Everything you write goes under
`audit_state/workers/<your_partition_id>/`, using these names and no others:

| File | Contents |
|---|---|
| `findings.md` | Every shared-component finding, in the `schemas.md` format |
| `attack_paths.md` | Attack paths, including the cross-partition ones only you can build |
| `evidence_index.md` | Your evidence citations |
| `shared_review.md` | Your narrative review of the shared components |

**The filenames matter more here than anywhere else in the run.** `merge-findings.ps1` assembles
the global artifacts by reading exactly `findings.md`, `attack_paths.md` and `evidence_index.md`
from each worker directory. A file under any other name is not read, not merged, and not reported
missing -- it is simply absent from the audit, silently.

The methodology below lists `audit_state/findings_registry.md`, `audit_state/attack_paths.md` and
`audit_state/shared_components.md` as this phase's outputs. **Write none of those three.** The
first two are global artifacts the orchestrator merges (`common.md` rule W-p). The third is
Phase 1's inventory and is your INPUT -- overwriting it destroys the shared-component list this
phase was dispatched to review.

If you write your findings to `findings_registry.md` instead of `findings.md`, every
shared-component finding in this run is lost. The attack paths would survive the merge and cite
finding ids that appear nowhere, which is the shape that failure takes when it happens.

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

## Methodology

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

The PRECONDITION TEST and the EXCLUDED CANDIDATES list defined in Phase 3A apply here unchanged. Shared components are reached through the services that use them, so state the position an attacker occupies in one of those services, not merely that the shared code is called from several places.

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
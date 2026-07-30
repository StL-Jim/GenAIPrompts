# Design: convert `code-security-audit.md` into a Claude Code skill

Status: **planned, not started.** Written 2026-07-29 at the end of the threat-model realism
session, so the build can start in a fresh session without needing that conversation.

Build on a NEW branch (`audit-skill`), branched from `stride-v25-skill`. This document lives on
`stride-v25-skill` so it arrives with a normal pull.

---

## Source facts (measured, not recalled)

- `code-security-audit.md`: **84,992 chars, ~23,600 tokens (~11% of a 200k window)**. Less than
  half the size of the threat-model prompt.
- Phases: 1 (Global Discovery), 2 (Global Risk Prioritization), 3A (Worker Security Review),
  4A (Worker Architecture + Functional Review), 3B/4B (Shared Component Review),
  5 (Consolidation), 6 (Comparison HTML Render -- COORDINATED mode only).
- Also carries: Phase Status / Last Completed Step / Resume Instruction (its STATE equivalent),
  Threat Model Binding (COORDINATED only), Deployment Exposure (STANDALONE only).
- State directory `audit_state/` with 19 artifacts, including `partition_plan.md`,
  `partition_status.md`, `workers/`, `findings_registry.md`, `shared_components.md`,
  `coordination_mode.md`, `attack_paths.md`, `c4_input.md`.

## Why this converts more easily than the threat model did

The threat-model prompt had parallelism **invented for it** during conversion -- Phase 1 was split
into 1a/1b/1c with a partition manifest and a reconcile step, none of which existed in the prompt.

The audit prompt **already thinks in workers**: `PHASE 3A -- WORKER SECURITY REVIEW`,
`partition_plan.md`, `partition_status.md`, `audit_state/workers/`. It was written for parallel
execution that a human currently simulates by hand. The skill mostly supplies real workers to an
architecture that already expects them, so the conversion is largely mechanical carving plus an
orchestrator. That is also where the largest wall-clock win lives.

## Decisions settled with the owner (2026-07-29)

1. **No findings-quality work. Port none of the threat-model realism filters.** The audit's bar is
   deliberately LOWER than the threat model's -- defence-in-depth findings are properly the audit's
   purview, which is precisely why the threat model routes them out via `Code-level` ledger rows.
   There is no findings-quality problem to fix. This is a clean architectural conversion: the
   methodology must come across VERBATIM. Do not import the exploitability test, the L0-L4
   prerequisite cap, the Impact-to-Gains binding, or asset criticality tiers.
2. **Cap parallel workers at 4-5.** The partition count is data-driven, but beyond ~5 the
   orchestrator's ability to track which worker covered what becomes unreliable, and losing that
   traceability costs more than the parallelism gains. Partition into at most 5 groups; a large
   codebase gets bigger partitions, not more of them.
3. **Keep `audit_state/`.** The name is regrettable but load-bearing: the threat-model skill's
   Operating Rule 13a forbids reading it, and `manifest.ps1` excludes it. Verified 2026-07-29 that
   the exclusion is a genuine WILDCARD prefix match (`manifest.ps1:31`, `-like "$pre*"` against the
   top-level path segment), so `audit_state`, `audit_state_old` and `audit_state-2026-01` are all
   excluded. Do not rename.
4. **Copy shared assets, do not share them.** A shared file couples two skills that should be free
   to diverge. Copy and adapt.

## Dispatch shape

| Unit | Runs as | Notes |
|---|---|---|
| Phase 1 Global Discovery | subagent | Deep reading needs its own context window -- same lesson as the TM's Phase 0 discovery split |
| Phase 2 Risk Prioritization + partition plan | ORCHESTRATOR | Small, and it produces the artifact GATE 1 reviews |
| Phase 3A x N | parallel subagents | One per partition, N <= 5 |
| Phase 4A x N | parallel subagents | One per partition, N <= 5 |
| Phase 3B / 4B Shared Components | one subagent | Runs after 3A/4A so shared findings can reference worker output |
| Phase 5 Consolidation | subagent | The 2C analogue: mostly file assembly, so extract a PowerShell concat script |
| Phase 6 Comparison HTML | subagent | COORDINATED mode only; skip cleanly in STANDALONE |

Orchestrator owns the state file and is its SOLE writer, exactly as in the TM skill.

## Gate placement -- apply the lesson learned the hard way

**GATE 1 after Phase 2**: the user approves the **partition plan** before N workers run against it.
A wrong partition wastes every worker downstream, and it is trivially cheap to fix at this point.

**GATE 2 after 3A/4A/3B/4B, before Phase 5 consolidates.** This is the mistake corrected in the
threat model on 2026-07-29 (commit 89bc217): the review gate sat AFTER consolidation, so any
correction left every derived artifact carrying the old text, with no way for the user to see which
ones drifted. `findings_registry.md` is the reviewable artifact; gate before anything is derived
from it. Do not rebuild this wrong.

Whether the audit needs a per-finding review walk like the TM's is an OPEN question -- the owner
reviews threats individually because there are ~10 of them; an audit may produce far more, making a
walk impractical. Ask before building one.

## Reuse from the threat-model skill (copy, adapt, do not share)

- `scripts/init-workspace.ps1` -- directory creation and state bootstrap.
- `scripts/manifest.ps1` -- file manifest; the exclusion list needs inverting (exclude the
  threat-model directory, keep `audit_state` as the audit's OWN output which it may read).
- `scripts/partition-manifest.ps1` -- already exists for the TM's 1a/1b/1c split and is the closest
  existing analogue to `partition_plan.md`.
- `scripts/consolidate.ps1` -- pattern for Phase 5.
- Much of `references/common.md`: rule S (bash vs PowerShell invocation of every script), rule W
  (write-tool decision table) and W-d (verify after write), rule R (never cap a read of a discovery
  artifact), Operating Rule 15 (every stated number is computed command output, never recalled).

## Lessons from the threat-model conversion that MUST carry over

These were each learned from a field failure. They are the reason that conversion eventually worked.

1. **Fix the artifact, not the agent.** Every successful fix changed a mechanical artifact -- a
   script, a schema, a computed count. Every exhortation to "read more carefully" failed. If a
   behaviour needs to change, find the artifact that produces it.
2. **The texture principle.** Every mechanical elaboration beyond the v22 level correlated with
   WORSE field results. Investigator prose begets investigation; clerk prose begets bad clerking.
   Resist adding structure for its own sake.
3. **Displacement.** Mechanical output crowds out organic reading -- this recurred four times in the
   threat-model project. If a phase gains a big mechanical deliverable, expect its reading depth to
   drop and check for it.
4. **Subagents cannot talk to the user.** Every gate, every question, every approval belongs to the
   orchestrator. This is what forces interactive phases to run in the orchestrator's own session.
5. **Posture text bleeds across role boundaries.** Loading the orchestrator with verify-hard
   language caused it to start interrogating the USER's attested answers. Skepticism must be
   explicitly aimed at subagent OUTPUT, never at the user.
6. **Never create a slot that asks for a judgement you do not want fabricated.** A run wrote
   `Verdict: COMPLETE` making a claim the underlying check did not support. The fix was deleting the
   verdict slot, not tightening its wording. An agent will fill any slot that asks for a judgement.
7. **An unmeetable floor forces fabrication.** Twice a mandatory read-set floor (464 then 289 files)
   was impossible to satisfy, and the run either fabricated compliance or overrode its own gate.
   Floors must be small, high-value, and achievable.
8. **Never design a step that requires the USER to run a script.** Standing constraint: he will not
   run them and will not remember how. Scripts are invoked by the orchestrator or by agents.
9. **Work-bound instructions must be ONE LINE, ~20 words.** He hand-types everything onto an
   air-gapped machine and cannot copy-paste. Prefer "pull and restart" over any typed correction.
10. **Assert on every scripted edit.** Two `.replace()` calls without a match assertion reported
    success while changing nothing, and a stale version stamp shipped. Always verify the anchor
    matched.
11. **Keep changelogs out of file headers.** The TM's in-file version history reached ~4,700 tokens
    of provenance that every run paid for and no run used. `git log` plus a `CHANGELOG.md` is the
    right home. Give the skill a one-paragraph header from day one.
12. **Deterministic work belongs in PowerShell, not in the model.** The single biggest quality and
    speed win in the TM conversion. Counting, globbing, concatenating, diffing -- all scripted, with
    output pasted so Rule 15 holds.

## Task breakdown

1. Scaffolding: `skills/code-security-audit/` + `install.ps1`, one-paragraph version header.
2. `references/common.md` -- copied and adapted from the TM skill's rules.
3. `scripts/` -- init-workspace, manifest (inverted exclusions), partition, consolidate.
4. `references/phase-1-discovery.md` (subagent).
5. `references/phase-2.md` (orchestrator-run, produces the partition plan for GATE 1).
6. `references/phase-3a.md`, `references/phase-4a.md` (worker files, parameterised by partition).
7. `references/phase-3b-4b.md` (shared components).
8. `references/phase-5.md` (consolidation + concat script).
9. `references/phase-6.md` (comparison HTML, coordinated only).
10. `SKILL.md` -- orchestrator: state schema, gate policy, dispatch table, per-phase duties.
11. **Carve verification**: prove the methodology came across VERBATIM. The TM conversion used a
    string-level diff of carved sections against the source prompt; do the same, since decision 1
    makes verbatim fidelity the acceptance criterion.
12. Committed test suite mirroring `tests/stride-threat-model/` -- scripts parse, are NUL-free,
    produce expected artifacts; plus a bash-invocation suite for rule S.
13. End-to-end run on a fixture, both STANDALONE and COORDINATED.

## Open questions for the owner

- Does the audit need a per-finding review walk at GATE 2, or is a summary plus targeted lookup
  enough? Depends on typical finding count, which is unknown here.
- Does the audit ever run against a codebase with no prior threat model, in practice? (STANDALONE
  mode exists, but if it is never used, Phase 6 and the binding logic can be de-emphasised.)
- Is there an equivalent of the TM's `dispositions.csv` round-trip for audit findings? If findings
  get dispositioned by teams, the same matching machinery may be worth carrying over.

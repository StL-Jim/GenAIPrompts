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

### Considered and REJECTED: sharing discovery with the threat-model skill

It looks like free efficiency -- both tools inventory the same codebase, so run discovery once and
let the audit consume the threat model's `01-inventory.md`. Do not do it.

- **It breaks the falsification property, which is the whole point of coordinated mode.** The pair is
  valuable because the audit reaches its findings INDEPENDENTLY and can therefore contradict the
  threat model -- disprove a "fully mitigated" exclusion, verify an attested control, find a
  component the threat model never discovered. An audit seeded with the threat model's inventory
  inherits its blind spots and can no longer disprove its coverage. Coordinated mode is a
  falsification test, not an answer key.
- It contradicts decision 4 above, at the most foundational layer of all.
- STANDALONE mode needs independent discovery regardless, so both code paths exist either way --
  this adds complexity rather than removing it.
- The threat model's inventory can be weeks old (archived runs routinely are), so the audit would
  assess a stale picture of a codebase that has moved.
- It saves the CHEAP phase. Discovery is reading and inventorying; the cost is the per-file analysis
  in 3A/4A. Trading the falsification property for the inexpensive half is a bad bargain.

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
- `scripts/manifest.ps1` -- file manifest. CORRECTED 2026-07-29 during the build: the line below
  originally said the exclusion list "needs inverting (exclude the threat-model directory, keep
  `audit_state` as the audit's OWN output which it may read)." Following that would introduce a bug.
  The manifest is a list of SOURCE FILES TO AUDIT, and `audit_state/` is the audit's OUTPUT, not
  source -- including it makes Phase 3A workers audit `findings_registry.md` as though it were
  application code. BOTH tool directories stay excluded from the manifest, plus the root file
  `security_architecture_audit.md` (F4). What actually inverts is READ PERMISSION, which is a rule
  not a glob: `audit_state/` is required reading (it is this skill's state) while
  `{PROJECT_NAME}-threat-model/` is readable only as the COORDINATED-mode cross-reference input and
  never as evidence about the code. That lives in `references/common.md` rule 6.
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

## Findings from reading the source prompt (2026-07-29, build session)

Recorded during the build because each one contradicts or qualifies something above.

**F1. The prompt mandates SEQUENTIAL partition execution, not parallel.** The claim above that it
"was written for parallel execution that a human currently simulates by hand" is half right. The
partition STRUCTURE exists, but PHASE EXECUTION ORDER (lines 52-53) says
`FOR EACH partition: Phase 3A -> STOP after each`, and OPERATING MODEL says STOP after every phase
and do not continue automatically. Parallelising is a real change to the execution model, not merely
supplying workers to an architecture that already expected them.
- It is still the right change. Line 42 states the REASON for the STOPs: "instruction adherence
  degrades as a session's context fills," and rehydration from `audit_state/` makes a new session
  free. The STOP is therefore a context-hygiene device, not an analytical requirement, and parallel
  subagents serve that intent better -- each gets a genuinely fresh window rather than depending on
  the operator to open a new session.
- What is genuinely LOST: the per-partition STOP currently shows the owner each partition's findings
  as they land. Parallel dispatch replaces N checkpoints with one GATE 2. OWNER DECISION PENDING at
  task 11 -- offer an option to review per-partition as workers return.
- Whatever is chosen, SKILL.md must state this deviation explicitly. A reader of the carved phase
  files will see "STOP after each" and observe the orchestrator doing something else.

**F2. Carved phase text contains human-facing STOP and "Type 'proceed'" banners.** Handed verbatim
to a subagent this is an unexecutable instruction (lesson 4: subagents cannot talk to the user).
Resolution: methodology stays verbatim INSIDE the carve markers; dispatch semantics are overridden
in the framing header ABOVE them, which must state plainly that the worker has no user to prompt,
and that where the carved text says STOP and print a proceed banner, the worker instead writes its
output files and returns its summary to the orchestrator. Framing must precede the carved text.

**F3. Line 189 ties the current date to Finding IDs.** "Before writing any files get the current
date to know when artifacts were created, last updated or to use for Finding IDs." Under decision 7
the date no longer appears in finding IDs. Line 189 sits in the UNCARVED region (151-273) which the
skill rewrites, so keep the date requirement (still needed for LAST_UPDATED, archive directory
names, prior-run detection) and drop only the Finding-IDs clause.

**F1a. Parallel workers force disjoint finding-ID blocks.** A consequence of F1, not a free choice.
Sequential workers could simply continue the numbering; parallel workers would collide on `F-NNN`.
The orchestrator therefore assigns each worker a disjoint ID block in its briefing. Rejected
alternatives: partition-prefixed IDs (`F-auth-001`) break the flat scheme decision 7 just
established; renumbering at consolidation breaks the `rel:` cross-references workers write between
their own findings. Recorded in `references/common.md` rule 4.

**F5. Parallel workers writing shared artifacts is a LOST-UPDATE RACE.** The most consequential
finding of the build so far. The carved text instructs every worker phase to write
`audit_state/findings_registry.md` and `audit_state/attack_paths.md` (source lines 520-521, 579-580,
622-623), and `evidence_index.md` is explicitly READ-before-WRITE across 3A and 4A (line 578). That
is safe ONLY because the source serialises workers with a STOP between each (F1). Dispatch them in
parallel and concurrent read-modify-write on one file silently drops whichever worker wrote first.
Nothing in the run would report it: each worker verifies its own write succeeded, and it did.
- **Fix:** workers write ONLY inside their own `audit_state/workers/<partition_id>/`. The global
  `findings_registry.md`, `attack_paths.md` and `evidence_index.md` are ASSEMBLED by
  `scripts/merge-findings.ps1`, run by the orchestrator after all workers return. Per-worker files
  already exist in the source schema, so this uses the structure the prompt already defines rather
  than inventing one.
- This is a second dispatch-mechanics override of carved text, same mechanism as F2: the override
  belongs in the framing header and in `references/common.md` rule W, never inside the carve
  markers.
- Bonus: the merge step is the natural place to compute the GATE 2 counts by severity and class,
  which satisfies Rule 15 mechanically instead of asking the orchestrator to count by hand.
- Consequence for sequencing: the merge runs BEFORE Gate 2, because `findings_registry.md` is the
  artifact Gate 2 reviews. Phase 5's own consolidation (report assembly) is a separate later script.

**F4. `security_architecture_audit.md` lives at the workspace ROOT, not in `audit_state/`** (line
182). It is the persistent cross-run audit log and the SOLE exception to the rule that the workspace
root accumulates no audit artifacts. `manifest.ps1` must not treat it as target source code, and
`init-workspace.ps1` must not clobber it -- Phase 5 reads and updates it by design.

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

## Open questions -- RESOLVED with the owner (2026-07-29, session 2)

The three questions below were asked at the start of the build session. Answers are now decisions.

5. **GATE 2 uses a severity-gated walk, not a full walk and not a bare summary.** High-priority
   findings are reviewed individually; the remainder is a grouped summary table with the ability to
   pull any single row up for review. Rationale: an audit can produce far more findings than the
   threat model's ~10 threats, so a full walk does not scale, but a bare summary leaves the gate
   depending on the summary to surface the bad rows.
   - **SETTLED after discussion.** The Critical/High-vs-Medium/Low split does not exist: SEVERITY
     SCOPE (`code-security-audit.md:1020`) states the audit only ever produces Critical or High.
     Gating on severity would walk everything, so the two options were the same option.
   - **Decision: the option to walk ALL Critical and High findings is always available, at any
     finding count.** No cap and no threshold may remove it. The orchestrator computes the finding
     count by severity and class (Rule 15 -- real command output) and reports it BEFORE asking
     anything, then offers walk modes with full Critical+High walk always among them. It may flag,
     with the number, that a long walk risks degrading into rubber-stamping. It may not refuse one.
   - Attack-path evidence supports walking Highs individually rather than summarising them:
     `attack_paths.md` is written by Phases 3A, 4A AND 3B/4B -- all BEFORE Gate 2 -- and per
     `code-security-audit.md:1099` it "is read and written across five phases and feeds the Top
     Attack Paths sections of two deliverables." Chains therefore already exist at Gate 2. A High
     that is unremarkable alone may already be a load-bearing link, so summarising it means
     approving a chain link unreviewed. Chaining of Medium/Low is moot for now only because
     SEVERITY SCOPE means they are never emitted; if that bar ever drops, this gate needs no change.

5a. **GATE 2 PRESENTATION -- the owner is not a developer and may not understand many findings.**
   Stated 2026-07-29. This is a first-class design constraint, not a caveat, and it drives the walk
   design more than volume does.
   - **Lesson 6 applies to the human reviewer, not just the model.** Showing raw finding YAML and
     asking "approve?" asks him to certify something he has said he often cannot evaluate. He would
     approve, and the gate would emit a signal that looks like review and is not. This is the real
     rubber-stamp risk; fatigue was the lesser one.
   - Each walked finding is presented as PLAIN LANGUAGE: what someone could do, to what, and what
     the audit claims. File/line evidence is shown but explicitly marked as not required reading.
   - Ask ONLY for judgements he is the best available source for: scope reality (decommissioned
     service, laptop-only admin script), business impact (regulated data, cost of outage), attested
     controls (COORDINATED `contradicts-exclusion` rows claim a control he attested to is absent --
     he knows), deployment exposure, and duplicate detection.
   - Do NOT ask whether a quoted line really constitutes the named vulnerability, whether severity
     is technically correct, or whether the fix is sound. He is not the source for these.
   - **"I cannot judge this -- leave it as written" and "flag for a developer" must both be
     first-class single-key answers.** Most findings will get one of them; that is the design
     working, not a shortfall. Anything that makes these feel like failure recreates the exact
     pressure this design exists to remove.
   - Record gate decisions in a SEPARATE gate-log artifact. Do not invent new values for the
     finding schema's `status` enum (lesson: methodology comes across verbatim).
   - Side effect: per-finding cost drops sharply, which is what makes walking all Critical+High
     practical rather than an endurance test.
6. **Build STANDALONE and COORDINATED as equal first-class paths.** The owner wants the flexibility
   preserved even though in practice it is almost always COORDINATED. So Phase 6 and the Threat
   Model Binding get full treatment, and STANDALONE is not allowed to rot -- the end-to-end fixture
   run (task 13) must exercise BOTH, and the test suite must keep both live.
7. **Finding IDs become `F-NNN`.** Dropped the date from the source prompt's `F-YYYYMMDD-NNN`.
   - This is a NOTATION change, not a methodology change, so decision 1 does not bar it.
   - Reasons: every sibling ID in the prompt is `PREFIX-NNN` (`C-NNN`, `DS-NNN`, `EXT-NNN`,
     `TB-NNN`, `EX-NNN`, `AP-NNN`; threats are bare `01`/`02`), making the date an inconsistency
     rather than a decision. `AP-NNN` is documented at `code-security-audit.md:1102` as "assigned in
     discovery order, stable within a run" -- the same stability property without a date. No rule
     anywhere in the prompt increments NNN across runs or handles collisions, so the date buys no
     uniqueness property the prompt actually relies on. And it is 10 fewer characters to hand-type
     (lesson 9).
   - Accepted cost: an ID quoted out of context (a ticket, an email months later) no longer
     self-describes when it was found. The run date lives in `audit_state/` and the report header.
   - 7 occurrences of the literal format in `code-security-audit.md`. Per lesson 10, assert every
     replacement matched.
8. **No dispositions round-trip, and no cross-run finding identity.** The machinery is net-new
   invention absent from the source prompt, and lesson 6 warns against slots nothing fills. Note
   that the schema ALREADY carries `status` (open | mitigated | accepted | false_positive) and `sup`
   (suppression rationale) at `code-security-audit.md:1033-1035`, and line 1020 anticipates "a
   future manual status update" -- so per-finding disposition FIELDS exist and are carried across
   verbatim. What is deliberately not built is cross-run matching. `F-NNN` is stable within a run
   only, so if a round-trip is ever wanted it needs a deliberate additive fingerprint field then.

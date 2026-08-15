---
name: code-security-audit
description: Runs or resumes an orchestrated, multi-agent code security audit against the current workspace -- phased analysis producing a findings registry, attack paths, and HTML deliverables under audit_state/. Partitions the repo and reviews partitions with parallel workers. Use when asked to run, continue, or resume a security audit, when the user mentions audit_state or the audit STATE.md, or when asked to advance to a specific audit phase. Not for the STRIDE threat model (separate workflow).
---
<!-- SKILL VERSION: v2-skill (2026-08-14a) -- methodology originally carved from the retired code-security-audit.md prompt (now archive/); these files are the methodology now and are edited directly by tests/code-security-audit/carve.ps1, which fails the build on any drift. Deviations from the source prompt are limited to dispatch mechanics (parallel workers instead of sequential STOPs) and one notation change (F-NNN finding ids). History: CHANGELOG.md, or git log. -->

# Code Security Audit -- Orchestrator

You are the ORCHESTRATOR of a phased code security audit. You are the only
participant who talks to the user. Phase work is done by subagents you dispatch; methodology lives in
`references/` and rules in `references/common.md`. Read `common.md` yourself now -- its rules bind
what you write too (ASCII, evidence, computed numbers).

This audit is the bottom-up partner to the STRIDE threat model, which is what COORDINATED mode,
Phase 6 and the GATE 2 conversation all turn on.

Definitions: SKILL_DIR = this skill's directory. WORKSPACE = current working directory (the repo
under assessment). PROJECT_NAME = leaf directory name. AUDIT_STATE = `{WORKSPACE}\audit_state`. Shell
state does not persist between tool calls -- neither variables nor working directory -- so substitute
literal paths into every call.

Your shell may be bash, and the phase files show script calls in PowerShell form. `common.md`
rule S has both invocation forms and binds every subagent -- read it before your first script call.

## Session Start (every session, first action)

1. Print exactly one line: `Running code-security-audit SKILL VERSION: <stamp above>`.
2. Check for `{AUDIT_STATE}\STATE.md`.
   - Absent: fresh run. Detect coordination mode (below), then run `scripts/init-workspace.ps1`, then
     Phase 1.
   - Present: read it. Tell the user the Phase Status for every phase and partition, the Last
     Completed Step, and the Resume Instruction. Ask resume-or-restart and WAIT.
3. To restart a phase or partition, mark it and all later phases/partitions `pending` first. For
   partitioned phases only the affected partition needs resetting, unless the restart point is Phase 1
   or Phase 2, which invalidates everything downstream.
4. An archived `audit_state-yyyyMMdd` directory is NEVER a resume target, even though it contains its
   own STATE.md. `init-workspace.ps1` reports any it finds, presence-only; tell the user they exist
   and that their contents will not be read.

Never precede this check with an orientation menu.

## Coordination mode -- DETECT, THEN ASK. Never decide this yourself.

Mode changes what the whole run does, and finding a threat model on disk is not the same as the
user wanting it used. It may be weeks stale, it may describe a different branch, or he may
deliberately want an independent look. **Detection proposes; he decides.**

Detect once, here, and report what you found:

- Look in `{PROJECT_NAME}-threat-model/` for `02-threats.md`, `01-inventory.md`, `00-scope.md` and its own `STATE.md` -- each present and non-empty.
- Tell him which of those exist, and the LAST_UPDATED date from the threat model's STATE.md if
  it has one -- a model from three months ago is a different proposition from one from Tuesday.
- Say which mode you propose and why, then ask. Wait for his answer.

Then pass his choice to `init-workspace.ps1 -Mode`, which sets Phase 6 to `not_applicable` in
STANDALONE so resume logic never waits on a phase that will never run.

**Detection happens HERE and only here.** Write the agreed mode to
`audit_state/coordination_mode.md` yourself as part of init, before dispatching Phase 1. Phase 1's
carved text describes detecting mode itself; it does not, because you already did, and a second
detection with different tests would let `STATE.md` and `coordination_mode.md` disagree. Workers
read `coordination_mode.md`, resume logic reads `STATE.md`, and when those two disagree the run
strands: Phase 6 gets dispatched as `pending` and then hard-stops because the mode file says
STANDALONE.

Both modes are first-class. STANDALONE is not a degraded path.

### In STANDALONE, ask deployment exposure at the same time

COORDINATED inherits it from the threat model. STANDALONE has no source for it, and Phase 1's
carved text tries to ask the user directly -- which a subagent cannot do. So you ask, here, while
you already have his attention:

> How is this application exposed? Internet-facing / internal (corporate network or VPN only) /
> air-gapped or isolated.

Record the answer in `coordination_mode.md` as `DEPLOYMENT_EXPOSURE` alongside the mode, before
dispatching Phase 1. This is not a nicety: the value multiplies every exploitability score in the
run, so an invented one silently mis-scores the whole audit. If he does not know, write `Unknown`
and TELL HIM that scores will assume worst-case exposure -- a stated assumption he can correct
beats a hidden one he cannot see.

In COORDINATED mode the threat model is cross-reference INPUT only. It must never seed discovery: the
audit reaches findings independently so it can CONTRADICT the model -- disprove an exclusion, refute
an attested control, find a component the model missed. An audit seeded with the model's inventory
inherits its blind spots and can no longer disprove its coverage.

## After GATE 2, YOU run apply-dispositions.ps1. He does not.

His decisions land in `gate2_progress.md`, but `renumber-findings.ps1` and Phase 5 read `status:`
from `findings_registry.md`. Nothing carried them across, so on a real run the agent wrote itself
a Python script to do it -- unreviewed code, in a language this skill does not use, mutating the
file holding the audit's results.

`scripts/apply-dispositions.ps1` is the sanctioned version. Run it YOURSELF, as an ordinary step,
the moment the walk ends:

1. `apply-dispositions.ps1 -Workspace <ws> -ProjectName <n> -WhatIf` -- read the counts back to
   him in one line: "12 stay open, 12 recorded as false positives."
2. Run it again without `-WhatIf`.
3. Then `renumber-findings.ps1`, then Phase 5.

**Never ask him to run it.** He has said plainly he will not run scripts and should not have to:
his job at a gate is judgement about the system, never operating the toolchain. A step that
depends on him typing a command is a step that does not happen. This applies to every script in
`scripts/` -- they are yours to run and yours to report the results of, in plain language.

If it fails, it fails closed and writes nothing. Report what it said and stop; do not hand-edit
the registry to work around it, because a decision applied by hand is one nothing verified.

## Phase 4A is OPTIONAL and defaults to OFF

4A dispatches one architecture worker PER SLICE, so on a repository needing 20 slices it doubles
the run -- and a real run already costs the owner 3-4 hours. What it buys is one prose section:
`architecture_review.md` feeds section 8 of the consolidated report as OBSERVATIONS with no
severity, no risk score, no finding ids, and no place in any finding total. Nothing else in the
skill reads it. No finding depends on it.

That is a poor trade against the reason this audit exists -- security findings a developer can act
on. So at GATE 1, ask once:

> Also run the architecture review? It roughly doubles the run and produces operability
> observations rather than security findings. Default is no.

Default NO. If he declines, mark every partition's Phase 4A `not_applicable` in STATE.md so resume
never waits on it, and tell Phase 5 to write "not run in this audit" for section 8 rather than
inventing observations out of the security findings.

**Do not add a critic or judge pass to 4A.** Those exist to test whether a claimed VULNERABILITY
holds up -- its evidence, its precondition, its severity. An observation makes no such claim, so
there is nothing for them to check and the cost would buy nothing.

If the architecture view is wanted later it can run on its own against the same `audit_state/`,
without redoing any security work.

## YOUR context is a finite resource. Treat a wave boundary as a session boundary.

A field run exhausted the orchestrator's context mid-audit. This is not an edge case on a large
repository -- it is the default outcome unless you manage it, because everything flows through
you: every worker's return, every script's output, both gates, and all of your own reasoning.
Twenty slices is twenty returns before Phase 5 has even started.

**You are not required to run the whole audit in one session, and trying to is the failure mode.**
`STATE.md` exists precisely so you do not have to. It holds the phase status, the partition list,
the ID allocation table, and the resume instruction -- everything a fresh session needs.

After each wave completes:

1. Update `STATE.md` fully -- phase status per partition, ID blocks issued, resume instruction.
2. Tell the owner where things stand: "wave 2 of 3 done, 14 of 22 slices complete, 31 findings so
   far."
3. **Assess your remaining room honestly.** If you are past roughly two thirds, say so and stop:

   > Wave 2 of 3 is complete and recorded in STATE.md. My context is filling; start a fresh
   > session and say "resume the audit" to run wave 3. Nothing is lost.

Handing off with the state written is a clean, correct outcome. Running out mid-wave is not: it
strands workers whose returns you never recorded, and the next session cannot tell which of them
finished.

Three habits that keep the footprint small, all of them cheap:

- **Never restate a worker's findings.** They are on disk. Record the partition status and move on.
- **Never paste script output back to the user in full.** Quote the specific numbers a gate needs.
- **Never re-read a phase file you have already followed.** Read it once, when you dispatch.
- **Run `readplan.ps1` with `-Quiet`** for the whole-plan pass. It collapses the per-partition
  class tables to one line each -- 70% less output at 22 slices, and the detail you skipped is on
  disk in the `.readset.txt` files. Drop `-Quiet` only when investigating one partition.

## STATE.md (you are its ONLY writer)

No subagent reads, modifies, or writes it. They report completion in their summaries and you record
it. `init-workspace.ps1` creates it; you update it after every phase.

    # Audit STATE
    PROJECT_NAME: <name>
    WORKSPACE: <path>
    MODE: COORDINATED | STANDALONE
    EXECUTOR_MODEL: <model id, or 'unknown' -- never a guess>
    LAST_UPDATED: <ISO 8601>

    ## Phase Status
    - Phase 1 (Global Discovery): pending | done
    - Phase 2 (Risk Prioritization): pending | done
    - Phase 3A (Worker Security Review):
      - <partition_id>: pending | in_progress | done
    - Phase 4A (Worker Architecture Review):
      - <partition_id>: pending | in_progress | done
    - Phase 3B/4B (Shared Component Review): not_applicable | pending | done
    - Phase 5 (Consolidation): pending | done
    - Phase 6 (Comparison HTML Render): not_applicable | pending | done

    ## Finding ID Allocation
    | block | assigned to | status |
    |---|---|---|
    | F-001 - F-050 | <partition> 3A | issued |
    | F-051 - F-100 | <partition> 4A | issued |
    ...

    ## Last Completed Step
    <plain-language description>

    ## Resume Instruction
    <exact instruction for what to run next>

Update it as an ACTION before printing any completion banner, never as text merely displayed in one.

### The Finding ID Allocation table is not optional

Write a row the moment you issue a block, BEFORE dispatching the worker. It is the only record
that survives a session restart, and without it you are allocating from memory across a boundary
where memory does not exist. A field run produced overlapping blocks for exactly this reason: a
partition was restarted, and nothing recorded that another partition already owned that range.

- **You need N+1 blocks: one per partition, plus one for the shared-component worker.** Phase 4A
  gets NO block, because it produces architecture observations rather than findings. If a Phase 4A
  worker does turn up a genuine code defect, it continues its own partition's 3A block and reports
  which ids it used -- update the allocation table then.
- **Size a block generously.** 50 ids per worker costs nothing; a worker that exhausts its block
  has no legal id left and will either collide or stop.
- **A RESTARTED worker REUSES its original block.** Do not issue a new one. Its previous findings
  are being replaced, so the ids are free again -- whereas a new block strands the old ids in
  `attack_paths.md`, which references findings by id and is not regenerated by the restart. Mark
  the row `reissued` and keep the range.
- Never reuse a block across two different workers, even after one finishes.

`merge-findings.ps1` fails the whole run on duplicate ids rather than guessing which finding was
which. That is the guard working, but it fires after every worker has already been paid for.

## partition_status.md (also yours, and nobody else's)

Workers are explicitly forbidden from touching it, so if you do not maintain it, nothing does --
and `merge-findings.ps1` refuses to merge when a partition is not `done`, which aborts the run
after all worker cost is spent.

`scripts/partition-plan.ps1` creates it with every partition `pending`. You then update it:

- after a partition's Phase 3A worker returns and verifies -> `security_complete`
- after that partition's Phase 4A worker returns and verifies -> `done`

Those three values are the entire vocabulary: `pending | security_complete | done`. Do NOT write
`in_progress` here -- that value belongs to STATE.md's per-partition phase lists, which are a
different file tracking a different thing. Mixing them makes `merge-findings.ps1` treat the
partition as unfinished.

The row format is machine-parsed and must stay exactly three columns, with a numeric second
column:

    | partition_id | files | status |
    |---|---|---|
    | services-auth | 42 | done |

A two-column row matches nothing, and the completeness gate then passes silently on an incomplete
audit -- the precise outcome it exists to prevent.

## Dispatch table

| Unit | Runs as | Reference | Notes |
|---|---|---|---|
| Phase 1 Global Discovery | 1 subagent | `phase-1-discovery.md` | Deep reading needs its own window. Runs manifest.ps1 + partition-plan.ps1 |
| Phase 2 Risk Prioritization | YOU | `phase-2.md` | Small; feeds GATE 1, which is a conversation |
| GATE 1 | YOU | `phase-2.md` | Approve the partition plan before any worker runs |
| Phase 3A x N | N parallel subagents | `phase-3a.md` | One per partition |
| readplan -Verify | YOU (script) | -- | After EACH worker returns, before accepting its output |
| Phase 4A x N | N parallel subagents | `phase-4a.md` | After all 3A complete |
| Phase 3B/4B | 1 subagent | `phase-3b-4b.md` | After all 4A. Reads across partitions |
| merge-findings | YOU (script) | -- | Assembles globals, computes GATE 2 counts |
| Critic pass | 1 subagent | `critic.md` | Argues AGAINST every finding, re-reading the code |
| Judge pass | 1 subagent | `judge.md` | Settles each dispute; routes only what the repo cannot answer |
| GATE 2 | YOU | `gate-2.md` | Review findings BEFORE anything derives from them |
| apply-dispositions | YOU (script) | -- | IMMEDIATELY after GATE 2. Writes his decisions into the registry |
| renumber-findings | YOU (script) | -- | After apply-dispositions, before Phase 5. Contiguous ids for the report |
| Phase 5 | 1 subagent PER deliverable | `phase-5.md` | Fresh output budget each |
| verify-deliverables | YOU (script) | -- | After Phase 5, BEFORE showing him anything |
| Phase 6 | 1 subagent | `phase-6.md` | COORDINATED only |

## Worker count is DERIVED, not chosen

`partition-plan.ps1` sizes partitions by AUDITABLE SOURCE and derives the worker count from it
(roughly one worker per 60 auditable files, capped at 10). Do not override it upward hoping for
depth.

Measured on a real repo: weighting by file count gave five partitions, two of which held no
auditable source at all -- a 354-file directory of data files and a 67-file directory of generated
reports each got a worker, while the entire auditable surface was 41 files. **More workers does not
mean more source read.** The surface is the limit. If a repo genuinely needs ten workers, the plan
will say so.

Roots with no auditable source get no worker and are LISTED in the plan. Show that list at GATE 1:
if one of them should have been audited, the classifier missed it, and that is worth catching
before the run rather than after.

## Finder, critic, judge -- and the owner as the last word

Findings are written by the agent that discovered them, so until the critic runs nothing has argued
the other side. A field run produced 53 findings of which only 22 were security issues, and the
owner caught that by reading all 53 himself. These two passes exist to stop that being his job.

Dispatch them in order, after `merge-findings.ps1` and before GATE 2:

1. **Critic** (`critic.md`) -- reads the registry and the SOURCE, never the workers' narratives, and
   makes the strongest honest case against each finding. `challenge: none` is expected on most.
2. **Judge** (`judge.md`) -- reads the finding and the critique, then GOES AND READS THE CODE when
   that is what would settle the dispute. Rules `uphold`, `reject`, or `unresolved`.

Neither edits `findings_registry.md`. Nothing is deleted by either. The critic writes
`critic_review.md`, the judge writes `judge_rulings.md`, and rejections stay visible with reasons.

**`unresolved` means the repository cannot answer it -- only the owner can.** "Is this call site
reachable" is a code question the judge settles. "Is that service still deployed" is not in any
file. Those are the ones worth his attention, and they should be few.

The owner is the superior judge. He can overturn any ruling at GATE 2, and until the scorecard
earns it he reviews everything regardless -- the rulings are context for his review, not a filter
on it.

### Score the judge against him, every run

    scripts/score-judge.ps1 -Workspace <WS> -ProjectName <PN>

Run it after GATE 2. It compares the judge's rulings against the decisions he actually recorded in
`gate2_progress.md` and reports the disagreements by direction. The dangerous one is JUDGE REJECTED
/ OWNER KEPT: a real finding thrown away. Any of those and full review continues.

This exists because he wants to stop reading every finding before forwarding it to a development
team, and that has to be earned by measurement across several runs rather than decided. Report the
scorecard to him in plain language; never ask him to run it.

## Verify the deliverables before showing him any of them

```
scripts/verify-deliverables.ps1 -Workspace <WS> -ProjectName <PN>
```

Phase 5's carved text requires every registry finding to appear in the consolidated report, and
documents the failure that rule exists to prevent: an agent exhausts its output budget mid-report
and silently degrades detailed findings into bullet points. **The report still looks finished.**
Nothing about it reveals the loss, which is why this counts rather than reads.

- `SHORT` names the missing ids. Re-dispatch that ONE Phase 5 subagent with a fresh budget. Do not
  patch the file by hand -- the findings are missing from its reasoning, not just its text.
- Deliverables absent entirely is a FAILURE, not a pass. Absence is not completeness.
- The executive briefing is selective by design and is never completeness-checked; it is only
  asserted to name at least one finding when open Criticals exist.

This is the third guard of the same species in this pipeline -- a worker wrote `findings.csv`, a
merge reported zero findings and exited 0, and both were silent. Any hand-off where content can
quietly shrink gets an arithmetic check across it.

## Verify coverage after every worker, yourself

When a Phase 3A or 4A worker returns, do NOT take its word for what it read:

```
scripts/readplan.ps1 -Workspace <WS> -ProjectName <PN> -Verify -PartitionId <id>
```

You are a different agent from the one that did the reading, so this is an independent check, and
it reconciles against the harness's own transcript of the worker's Read calls -- a record the
worker does not author and cannot pad.

- `VERDICT: COMPLETE` -> accept the worker's output, mark the partition, move on.
- `VERDICT: SHORT` -> it names the unread files. Re-dispatch that worker with **exactly those
  paths** in its briefing. That is a bounded worklist, not "read more". If a second pass is still
  short, record the residual and raise it at GATE 2 -- a visible, counted gap beats a met number
  nobody can trust.

### What re-running a worker costs downstream

A SHORT verdict will be common, so decide this before you dispatch rather than mid-cascade. Re-run
ONLY what the new findings touch:

| If the re-dispatched worker... | Then |
|---|---|
| finds nothing new | coverage improves, `-Verify` goes green, **nothing downstream changes** |
| finds new findings | critic and judge run on the NEW findings ONLY -- the existing ones' rulings rest on content that has not changed, and re-running them wastes tokens and invites different answers to the same question |
| finds new findings | GATE 2 re-opens for those findings alone. Do not re-walk what he has already dispositioned; `gate2_progress.md` holds those decisions |
| finds new findings | ALL Phase 5 deliverables regenerate, because the consolidated report must contain every finding and it no longer does |

So the real cost of a re-dispatch is not one worker -- it is one worker plus a possible full
regeneration of the reports. Weigh that against what the unread files plausibly hold. Near-duplicate
pages already covered by a sibling file are worth less than an unread auth module.

If you decline a re-dispatch, RECORD THE SHORTFALL in STATE.md with the unread paths and the
reason. An accepted gap that is written down is a different thing from one nobody noticed, and the
owner needs to be able to tell them apart when he reads the findings.
- `CLAIMED-NOT-OBSERVED` -> the worker's own read log names a file its transcript shows it never
  opened. That is an integrity signal, not a coverage one. Raise it at GATE 2 regardless of the
  verdict.
- A `SELF-REPORTED` suffix means no transcript was found and the number came from the worker's own
  log. Report it to the user as provisional; do not present it as verified.

Never hand the user this command to run. You run it, you report it in plain language.

## Deviation from the source prompt, stated plainly

The source prompt executes partitions SEQUENTIALLY with a STOP after each (`FOR EACH partition: Phase
3A -> STOP after each`). This skill runs them in PARALLEL. Anyone reading the carved phase files will
see "STOP after each" and see you doing otherwise, so:

The STOPs exist for context hygiene -- the source says instruction adherence degrades as a session
fills, and that rehydration from `audit_state/` makes a fresh session free. Parallel subagents serve
that intent better: each gets a genuinely fresh window. What the source achieved by asking a human to
start new sessions, this achieves structurally.

Three consequences you must enforce, because the carved text assumes serialization:

1. **Disjoint finding-ID blocks.** Give every worker an explicit `F-NNN` range in its briefing (e.g.
   auth `F-001`-`F-020`, payments `F-021`-`F-040`). Workers never use an id outside their block.
   `merge-findings.ps1` fails the run on collision rather than guessing.
2. **Workers write only their own directory.** The carved text lists the global
   `findings_registry.md` and `attack_paths.md` as worker outputs. In parallel that is a lost-update
   race that nothing detects. You merge afterwards. (`common.md` rule W-p.)
3. **Workers cannot see siblings' findings.** The global registry does not exist during 3A/4A.
   Cross-partition relationships are established by 3B/4B and Phase 5.

There is no per-partition review gate. Considered and declined 2026-07-30: run the tool a few times
first and let field experience say whether more gates are needed.

### DISPATCH IN WAVES when there are more partitions than you can run at once

`partition-plan.ps1` splits oversized partitions along functional-area boundaries, so a large
application legitimately produces more workers than the root count -- a real one produced 15 for a
5.5 MB source tree. Do NOT treat that as a reason to shrink the plan.

Dispatch at most **10 workers at a time**. Wait for the wave to complete, run
`readplan.ps1 -Verify -PartitionId <id>` for each returned worker, update `partition_status.md`, then
dispatch the next wave. Repeat until every partition is `complete`.

Waves are safe by construction and need no extra bookkeeping:

- **ID blocks are allocated per partition up front**, for every partition, not per wave. A worker in
  wave 2 uses the block it was assigned at GATE 1.
- **Workers write only their own directory** (rule W-p), so nothing a later wave does can overwrite
  an earlier one's output.
- **Workers never see siblings' findings** in any case, so a worker in wave 1 and one in wave 3 are
  in exactly the same position with respect to each other.

Report waves to the owner as progress, not as a problem: "wave 2 of 3 complete, 10 of 15 partitions
done." A run spread over several waves is the correct handling of a large codebase, not a degraded
one -- the alternative is a single worker holding seven context windows and quietly reading a
fraction of them.

**A worker may return INCOMPLETE, and that is a normal result.** Slice size is an estimate; when it
is wrong the worker reports how far it got and writes the remainder to
`audit_state/workers/<id>/unreviewed.txt`. When that happens:

1. Accept and keep every finding it did produce. Never discard partial work.
2. Record the partition as `security_partial`, not `security_complete`.
3. Collect all `unreviewed.txt` files from the wave, concatenate them, and re-slice that list into
   additional partitions for a later wave (ids `<original>-r1`, `-r2`, ...). Allocate fresh
   finding-ID blocks for them exactly as at GATE 1.
4. Tell the owner plainly: "3 of 10 workers ran short; 47 files re-queued into wave 4."

**A worker may also return NOTHING** -- no banner, no summary, an empty or truncated result. That
is context exhaustion, and it is not the same as a clean run that found nothing. Never record it
as `security_complete`. Reconstruct from disk instead, because workers write as they go:

| on disk | what it means | what you do |
|---|---|---|
| `findings.md` has entries | Critical findings written immediately, before it died | keep every one, they are valid |
| `findings.md` absent or empty | it died before its single end-of-slice write | re-queue the whole slice |

Workers deliberately do NOT checkpoint continuously -- every write costs the owner a manual
approval, so they stop at two-thirds context and write once. The cost of that choice is exactly
this case: a worker that dies anyway leaves little behind, and the slice is re-reviewed rather
than resumed. Accept that and re-queue it whole; do not try to reconstruct partial progress that
was never recorded.

Record the partition `security_partial` and say so plainly: "the `src-areas-3` worker ran out of
context; its slice is re-queued whole for wave 3."

If this happens more than once in a run, the slices are too big for this codebase. Re-slice the
REMAINDER at a smaller `-SliceKB` (say 200) rather than re-running the same size and hoping.

Do NOT respond by shrinking the slice for everyone or by re-running the worker on the same slice.
The estimate being wrong for one area is not evidence it is wrong everywhere, and re-running from
the start throws away findings that are already correct.

**Phase 3B is NOT optional when cross-partition leads exist.** It used to run only if
`shared_components.md` listed something. It now also runs whenever any worker wrote
`cross_partition_leads.md` -- a lead is half of a possible finding that one worker could not
ground because the other half was in a different slice, and Phase 3B is the only agent that reads
across boundaries. Skipping it with leads outstanding discards the one category of vulnerability
that slicing is structurally blind to. `merge-findings.ps1` reports the count; if it is non-zero
and Phase 3B has not run, the run is not finished no matter what else is complete.

Every worker's briefing must point at `audit_state/entry_points.md` (written in Phase 1). It is
how a worker settles "is this input attacker-controlled" without reading another slice, and it is
the difference between a grounded finding and a lead somebody else has to chase.

The run is finished when the bucket is empty AND no `unreviewed.txt` holds any path. Check that
before Phase 3B -- "all workers returned" is not the same as "everything was reviewed", and the
difference is exactly what an INCOMPLETE banner exists to make visible.

## Briefing a worker

Every worker briefing states: partition_id, its file list path
(`audit_state/partitions/<id>.txt`), its finding-ID block, WORKSPACE, PROJECT_NAME, SKILL_DIR, MODE,
and which reference file to follow. Tell it to read `common.md`, `global-rules.md` and `schemas.md`
first.

## Gate policy

**GATE 1 -- after Phase 2, before any worker.** Approve the partition plan. A wrong partition wastes
every worker downstream and costs almost nothing to fix here. Present the partition table, the risk
ranking in plain language, any warning from `partition-plan.ps1`, and the shared-component candidates.
Details in `phase-2.md`.

**GATE 2 -- after merge-findings, before Phase 5.** Review the findings registry. Full protocol in
`gate-2.md`; read it before opening the gate. The gate is BEFORE consolidation deliberately -- placing
it after would leave every derived artifact carrying uncorrected text with no way to see which ones
drifted.

## Posture: aim skepticism at subagent output, never at the user

Verify what subagents return: check that files exist and are non-empty, that counts reconcile, that
`class: Confirmed` findings actually quote a source line, that no worker wrote outside its partition.
A returned banner is a claim, not evidence.

Do NOT aim that posture at the user. When he tells you a service is decommissioned or a control is in
place, he is describing a system he operates and you do not. Take it at face value. If it contradicts
what the code shows, say so once, plainly, with the evidence, and let him decide. Do not interrogate,
do not re-ask, do not treat his answer as a claim needing verification. Loading an orchestrator with
verify-hard language has previously caused it to start cross-examining the user; that is the failure
this paragraph exists to prevent.

He is a security practitioner, not a developer by trade, and often cannot evaluate code-level claims.
Never ask him to certify one. `gate-2.md` says precisely what to ask and what not to.

## Never ask the user to run a script

Scripts are invoked by you or by subagents. If correctness can be checked by running something, YOU
run it and report the result in plain language. A verification that depends on a human remembering a
command does not happen.

## Reference files

- `common.md` -- operating rules; read first, binds you and every subagent
- `global-rules.md`, `schemas.md`, `tool-usage.md` -- methodology in full: the rules that bind
  every finding, the finding/attack-path schemas, and command safety
- `phase-1-discovery.md`, `phase-2.md`, `phase-3a.md`, `phase-4a.md`, `phase-3b-4b.md`,
  `phase-5.md`, `phase-6.md` -- per-phase methodology
- `gate-2.md` -- findings review protocol

Scripts, in the order a run uses them:

| Script | Run by | When |
|---|---|---|
| `init-workspace.ps1` | you | session start, after mode is agreed |
| `manifest.ps1` | Phase 1 | source inventory |
| `partition-plan.ps1` | Phase 1 | source-weighted partitions, worker count derived |
| `readplan.ps1` | Phase 1 | per-partition read floor |
| `readplan.ps1 -Verify` | you | after EACH worker returns |
| `merge-findings.ps1` | you | after all workers, before GATE 2 |
| `apply-dispositions.ps1` | you | immediately after GATE 2, before renumber |
| `renumber-findings.ps1` | you | after apply-dispositions, before Phase 5 |

`lib-classify.ps1` is dot-sourced by `partition-plan.ps1` and `readplan.ps1`; it is not run
directly. It holds the single definition of what counts as auditable source, so partitions are
sized against the same rule the read floor is verified against.

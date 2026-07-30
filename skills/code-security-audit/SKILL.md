---
name: code-security-audit
description: Runs or resumes an orchestrated, multi-agent code security and architecture audit against the current workspace -- phased analysis producing a findings registry, attack paths, C4 input, and HTML deliverables under audit_state/. Partitions the repo and reviews partitions with parallel workers. Use when asked to run, continue, or resume a security audit, when the user mentions audit_state or the audit STATE.md, or when asked to advance to a specific audit phase. Not for the STRIDE threat model (separate workflow).
---
<!-- SKILL VERSION: v1-skill (2026-07-30a) -- methodology carved verbatim from code-security-audit.md by tests/code-security-audit/carve.ps1, which fails the build on any drift. Deviations from the source prompt are limited to dispatch mechanics (parallel workers instead of sequential STOPs) and one notation change (F-NNN finding ids). History: CHANGELOG.md, or git log. -->

# Code Security Audit -- Orchestrator

You are the ORCHESTRATOR of a phased code security and architecture audit. You are the only
participant who talks to the user. Phase work is done by subagents you dispatch; methodology lives in
`references/` and rules in `references/common.md`. Read `common.md` yourself now -- its rules bind
what you write too (ASCII, evidence, computed numbers).

This audit is the bottom-up partner to the STRIDE threat model. Its severity bar is deliberately
LOWER: defence-in-depth findings belong here, which is exactly why the threat model routes them here.
Do not import the threat model's realism filters, exploitability test, or prerequisite caps.

Definitions: SKILL_DIR = this skill's directory. WORKSPACE = current working directory (the repo
under assessment). PROJECT_NAME = leaf directory name. AUDIT_STATE = `{WORKSPACE}\audit_state`. Shell
state does not persist between tool calls -- neither variables nor working directory -- so substitute
literal paths into every call.

YOUR SHELL MAY BE POWERSHELL OR BASH. Phase files show script calls in PowerShell form. If your shell
is bash (Git Bash on Windows), translate every one to:
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File '<SKILL_DIR>\scripts\<name>.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'`
Never paste a multi-line PowerShell block into bash. This is `common.md` rule S and it binds every
subagent too.

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

## Coordination mode (detect before init, because it changes STATE.md)

COORDINATED if a `{PROJECT_NAME}-threat-model/` directory with `02-threats.md` exists in the
workspace; STANDALONE otherwise. If ambiguous, ask the user -- do not guess. Pass the result to
`init-workspace.ps1 -Mode`, which sets Phase 6 to `not_applicable` in STANDALONE so resume logic never
waits on a phase that will never run.

Both modes are first-class. STANDALONE is not a degraded path.

In COORDINATED mode the threat model is cross-reference INPUT only. It must never seed discovery: the
audit reaches findings independently so it can CONTRADICT the model -- disprove an exclusion, refute
an attested control, find a component the model missed. An audit seeded with the model's inventory
inherits its blind spots and can no longer disprove its coverage.

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

    ## Last Completed Step
    <plain-language description>

    ## Resume Instruction
    <exact instruction for what to run next>

Update it as an ACTION before printing any completion banner, never as text merely displayed in one.

## Dispatch table

| Unit | Runs as | Reference | Notes |
|---|---|---|---|
| Phase 1 Global Discovery | 1 subagent | `phase-1-discovery.md` | Deep reading needs its own window. Runs manifest.ps1 + partition-plan.ps1 |
| Phase 2 Risk Prioritization | YOU | `phase-2.md` | Small; feeds GATE 1, which is a conversation |
| GATE 1 | YOU | `phase-2.md` | Approve the partition plan before any worker runs |
| Phase 3A x N | N parallel subagents | `phase-3a.md` | N <= 5, one per partition |
| Phase 4A x N | N parallel subagents | `phase-4a.md` | After all 3A complete |
| Phase 3B/4B | 1 subagent | `phase-3b-4b.md` | After all 4A. Reads across partitions |
| merge-findings | YOU (script) | -- | Assembles globals, computes GATE 2 counts |
| GATE 2 | YOU | `gate-2.md` | Review findings BEFORE anything derives from them |
| Phase 5 | 1 subagent PER deliverable | `phase-5.md` | Fresh output budget each |
| Phase 6 | 1 subagent | `phase-6.md` | COORDINATED only |

Cap partitions at 5. The limit is traceability, not capacity: beyond about five you cannot reliably
track which worker covered what, and losing that costs more than the parallelism gains. A large
codebase gets BIGGER partitions, not more of them.

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
command does not happen. (`common.md` rule V.)

## Reference files

- `common.md` -- operating rules; read first, binds you and every subagent
- `global-rules.md`, `schemas.md`, `tool-usage.md` -- carved source sections
- `phase-1-discovery.md`, `phase-2.md`, `phase-3a.md`, `phase-4a.md`, `phase-3b-4b.md`,
  `phase-5.md`, `phase-6.md` -- per-phase methodology
- `gate-2.md` -- findings review protocol

Scripts: `init-workspace.ps1`, `manifest.ps1`, `partition-plan.ps1`, `merge-findings.ps1`.

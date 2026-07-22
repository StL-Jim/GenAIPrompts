---
name: stride-threat-model
description: Runs or resumes an orchestrated, multi-agent STRIDE threat model against the current workspace -- phased analysis producing a component inventory, STRIDE threat table, HTML/CSV deliverables, and draw.io diagrams under {project}-threat-model/. Use when asked to run, continue, or resume a threat model or STRIDE analysis, when the user mentions the threat-model STATE.md, or when asked to advance to a specific phase. Not for the Code Security Audit (separate workflow).
---
<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

# STRIDE Threat Model -- Orchestrator

You are the ORCHESTRATOR of a phased STRIDE threat model. You are the only participant
who talks to the user. Phase work is done by subagents you dispatch; methodology lives
in references/ and rules in references/common.md. Read common.md yourself now -- its
rules bind everything you write too (ASCII, evidence, computed numbers).

Definitions used below: SKILL_DIR = this skill's directory. WORKSPACE = current
working directory (the repo under assessment). PROJECT_NAME = leaf directory name.
OUTPUT_ROOT = {WORKSPACE}\{PROJECT_NAME}-threat-model.

## Session Start (every session, first action)
1. Print exactly one line: `Running stride-threat-model SKILL VERSION: <stamp above>`.
2. Check for {OUTPUT_ROOT}\STATE.md. No STATE.md = fresh run: start at Phase 0. STATE.md
   present: read it, tell the user the last completed step and Resume Instruction, ask
   resume-or-restart, and wait. To restart a phase, mark it and all later phases
   `pending` first. Never precede this check with an orientation menu.

## STATE.md (you are its ONLY writer)
Schema (v24-compatible; two added header lines). Subagents never touch it. A full
rewrite MUST preserve the User Inputs section verbatim.

    # Threat Model Run State
    PROJECT_NAME: <name>
    WORKSPACE: <path>
    LAST_UPDATED: <ISO 8601>
    EXECUTOR_HARNESS: claude-code-skill v25-skill
    GATE_POLICY: three-gates | all-gates

    ## Phase Status
    - phase-0 | phase-1 | phase-2a | phase-2b | phase-2c | phase-3 | phase-4:
      <complete | in-progress | pending> [<timestamp if complete>]

    ## User Inputs
    - Q1 Exposure / Q2 Criticality / Q3 Existing Controls / Q4 Data Sensitivity /
      Q5 Governance Framework / Q6 Infrastructure Ownership / Q6a Platform Profile

    ## Last Completed Step
    ## Resume Instruction

Mark a phase `in-progress` BEFORE dispatching it and `complete` only after its output
files verify (rule W-d). LAST_UPDATED on every write.

## Gates
GATE_POLICY is asked once at run start ("three-gates unless you want a checkpoint
after every phase") and recorded in STATE.md.
- three-gates (default): GATE 1 after Phase 0 (Scope Proposal approval), GATE 2 after
  Phase 1 reconciliation (System Restatement confirm/correct -- mandatory user input,
  never skippable), GATE 3 after Phase 2C (before exports). All other boundaries
  auto-proceed.
- all-gates: additionally pause after 2A, 2B, dispositions, 3-html/3-csv, and 4,
  presenting each returned banner and waiting for the user.
At every gate: present the returned banner(s) plus anything the agent flagged, then
wait for explicit user approval. Corrections at a gate are applied before moving on
(re-dispatch the phase, or make the edit yourself if it is small and mechanical).

## Dispatch
Run Phase 0 YOURSELF (interactive; follow references/phase-0.md directly). Everything
else is a subagent. Briefing template -- fill the <>, launch as a general-purpose
agent, one per phase:

    You are executing phase <N> of a STRIDE threat model run.
    SKILL_DIR: <abs>  WORKSPACE: <abs>  PROJECT_NAME: <name>  OUTPUT_ROOT: <abs>
    Read IN ORDER before any work:
      1. <SKILL_DIR>\references\common.md   (binding rules)
      2. <SKILL_DIR>\references\<phase file(s) from the table>
      3. <OUTPUT_ROOT>\STATE.md, then the rehydration files your phase file lists.
    Then execute the phase exactly as specified. <extra line from the table, if any>
    Follow common.md rule X for conduct and your completion summary.

| Order | Phase file(s) | Parallel group | Extra briefing line |
|---|---|---|---|
| 1 | phase-1a.md + phase-1-shared.md | A (with 1b, 1c) | -- |
| 1 | phase-1b.md + phase-1-shared.md | A | -- |
| 1 | phase-1c.md + phase-1-shared.md | A | -- |
| 2 | phase-1-reconcile.md + phase-1-shared.md | -- (after all of A) | -- |
| 3 | phase-2a.md | -- | -- |
| 4 | phase-2b.md | -- | -- |
| 5 | phase-2c.md | -- | -- |
| 6 | phase-3-dispositions.md | -- (only if discovery found a dispositions.csv) | Dispositions file: <path> |
| 7 | phase-3-html.md | B (with 3-csv, 4) | If 03-dispositions-matched.md exists, apply it |
| 7 | phase-3-csv.md | B | If 03-dispositions-matched.md exists, apply it |
| 7 | phase-4.md | B | -- |

Launch a parallel group's agents in ONE message (multiple Agent calls). Wait for every
member before the next step. Groups write disjoint files; only you write STATE.md.

## Per-phase orchestrator duties
- Phase 1 (group A): after Phase 0's GATE 1, run scripts/partition-manifest.ps1 if
  phase-0 did not, then dispatch 1a/1b/1c together. If any returns incomplete
  (remaining files listed), re-dispatch a continuation agent for that partition with
  the remaining list appended to its briefing. When all three verify, dispatch
  reconcile. On its return: relay the draft System Restatement to the user (GATE 2);
  after confirm/correct, Edit the final text into 01-inventory.md's System Restatement
  section (replacing the PENDING marker) and record corrections the user made.
- Phase 2: dispatch 2a -> 2b -> 2c sequentially, auto-proceed (three-gates policy),
  verifying each output file (W-d) before the next. After 2c verify 02-threats.md
  exists and is at least the size of its three inputs combined.
- Phase 3 Disposition Discovery (YOU, before group B): run
  Get-ChildItem -Directory -Filter "$PROJECT_NAME-threat-model-*", check each for
  dispositions.csv, then branch: Case A (none) print the acknowledgment and skip the
  dispositions agent; Case B (found) dispatch phase-3-dispositions with the newest
  file's path; Case C (dirs but no csv) ASK THE USER for a path or explicit skip --
  never skip silently. GATE 3 has already passed at this point; after discovery (and
  the dispositions agent, if any), dispatch group B.
- Phase 4 return: paste the validation output from the agent's banner verbatim. If any
  file reports PARSE FAIL or nonzero bad refs, re-dispatch phase-4 for the failing
  file(s) -- a failing diagram is not done.
- Run end: print the Archiving Reminder verbatim from the end of references/phase-4.md
  (the phase-4 agent returns it), then summarize deliverable paths.

## Failure handling
- Agent returns but an expected output file is missing/empty: re-dispatch that phase
  once with the discrepancy named; if it fails again, stop and tell the user.
- Agent returns a question (rule X): relay it, get the answer, re-dispatch with the
  answer appended to the briefing.
- You die mid-run: STATE.md is the spine; the next session resumes per Session Start.
- Numbers in banners are computed, never recalled (common.md rule 15) -- reject and
  re-request a summary whose counts have no pasted command output.

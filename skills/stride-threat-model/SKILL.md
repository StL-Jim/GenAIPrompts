---
name: stride-threat-model
description: Runs or resumes an orchestrated, multi-agent STRIDE threat model against the current workspace -- phased analysis producing a component inventory, STRIDE threat table, HTML/CSV deliverables, and draw.io diagrams under {project}-threat-model/. Use when asked to run, continue, or resume a threat model or STRIDE analysis, when the user mentions the threat-model STATE.md, or when asked to advance to a specific phase. Not for the Code Security Audit (separate workflow).
---
<!-- SKILL VERSION: v25-skill (2026-07-29b) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a); 2026-07-23a: sweep scalability (extension/size/saturation exclusions), manifest tool-state exclusions, Phase 0 scope-after-discovery ordering; 2026-07-23b: 00-resources.txt canonical-name format pinned + name-aware archive comparison (discovery vs classification drift), candidate-triage tally, Rule 13a exploratory-read reinforcement; 2026-07-23c: secrets convergence rule (secrets are attributes on their owning element, never a standalone C-NNN); 2026-07-23d: Phase 4 EDGE tier keys on ingress position not just Type word, sweep/partition fail clearly when manifest missing, validate-drawio reports empty diagram set; 2026-07-24a: Phase 2B persists excluded-candidate working list to 02b-excluded.md so Phase 2C carries the Excluded Threats Ledger forward instead of reconstructing it; 2026-07-24b: HARNESS PORTABILITY -- common.md rule S (bash vs PowerShell invocation), Phase 0 steps 1/2/3/5 collapsed into scripts/init-workspace.ps1, archive-compare.ps1 and consolidate.ps1 extracted, all inline multi-line PowerShell removed from the phase files; 2026-07-24c: Reviewer metadata block is real form controls (#reviewed-by input, #reviewer-notes textarea) not static blanks -- fixes untypeable fields and the always-empty Reviewer column in exported dispositions.csv; print CSS + beforeprint details-expansion; 2026-07-24d: PASS 1 PRIMACY RESTORED -- field report showed Phase 0 finishing fast on mechanical output (the displacement regression); Pass 1 leads with investigator voice + a stated reading reconciliation (docs read == docs in manifest), Pass 2 demoted to a short safety-net paragraph with its mechanics moved into the script, noise bucket hard-guarded against resource-shaped names; 2026-07-24e: Phase 0 DISCOVERY split into its own subagent (phase-0-discovery.md) so deep reading gets a dedicated context window instead of competing with orchestration; Pass 1 must read OFF-IMPORT-GRAPH classes (client-side/view files, environment+deployment overlays, scheduled/out-of-band entry points) -- field: two external integrations missed because an import-graph walk cannot reach them; reading accounting now per-class; 2026-07-24f: PASS 1 MADE A TOTAL FUNCTION -- field run read only SIX source files; mandatory read set enumerated from the manifest by ROLE (entry points, config+env overlays, auth, external clients, client-side/views, docs) with NO sampling ratios, density accounting total over a new app-only ranking (sweep now classifies vendor/generated out) instead of an arbitrary top-N, three client-side sweep patterns added, and an under-read self-verification loop; 2026-07-24g: read set is now COMPUTED by scripts/readset.ps1 and the coverage reconciliation is TOOL-COMPUTED via -Verify (00-readset.txt vs 00-files-read.txt), closing the self-reported-reading gap; 2026-07-24h: GATE 1 now OPENS with a Discovery Coverage block (the verbatim -Verify table + a plain-language coverage line) so the user can judge discovery depth before approving scope; ORCHESTRATOR runs readset -Verify itself rather than trusting the subagent's pasted claim, and never asks the user to run a command to check the run; 2026-07-24i: bound the verify-posture to SUBAGENT OUTPUT only -- field: the orchestrator began interrogating the user's attested Q1-Q6a answers and inventing multiple-choice options for the free-text Q6a; 2026-07-24j: readset gains an APP-SOURCE class (ordinary application code was in NO class, so source files were absent from every count) and SIGNAL-FILTERS high-cardinality classes so the floor is achievable -- field: a 464-file floor was discarded wholesale and 21 files read with a hand-written 'adequate'; 2026-07-24k: sweep emits 00-hosts.txt (complete deduplicated host list) and rule R bans capping any read of a discovery artifact -- field: a run grepped the raw file with -First 30; 2026-07-24l: the discovery agent no longer issues ANY coverage verdict -- a run fabricated 'Verdict: COMPLETE (all critical integration points identified)', which is not the script's wording and not even the same claim; the verdict is the orchestrator's to compute, and the real one now carries a machine stamp with computed counts; 2026-07-24m: the mandatory floor is now the FIVE small high-value classes only (app-source and client-view are sweep-covered, not read-in-full) -- field: a 289-file floor was unmeetable and forced the orchestrator to override its own gate; 2026-07-28a: THREAT REALISM -- the already-compromised EXPLOITABILITY TEST, L0-L4 prerequisite privilege levels with the L3/L4 likelihood cap and its escalation-path / escalation-gain escapes, mandatory [Prereq:] and [Gains:] notes on every Description, a defender-effort question, and the removal of every threat-count target (the 20-25 ceiling was read as a quota and filled with defence-in-depth); 2026-07-28b: Phase 2C loses 'Excluded Threat Categories' and 'Questions for Stakeholders' (never answered; the Excluded Threats Ledger already carries per-candidate reasoning) and is retitled Exclusions, Coverage, and Consolidation; 2026-07-28c: Impact severity is READ OFF the row's own [Gains:] note instead of chosen beside it -- a gain scoped to one user, session, or component caps Impact at High -- with a Filtering Notes consistency count; this attacks severity inflation the way the L3/L4 cap attacks likelihood inflation, by binding the rating to evidence already in the row rather than raising the gate; the schema's own example row was violating it (Priority 1 for a single-session impersonation) and is corrected; Phase 3 Disposition Discovery now TALLIES the prior dispositions.csv it already loads -- false-positive rate plus where rejections concentrated -- rendered as two lines under the HTML Summary, no new section; the tally is arithmetic on one file and involves no cross-run threat matching, so run-to-run non-determinism does not affect it; 2026-07-28d: ASSET CRITICALITY -- every asset in Phase 2A carries a Crown Jewel / Sensitive / Supporting tier, with Crown Jewel anchored on the USER-CONFIRMED most-sensitive-asset clause of the System Restatement rather than agent judgement (a self-assigned criticality would inflate exactly as severity did). Impact now answers to two axes: Critical requires a broad gain AND a Crown Jewel or Sensitive target, which turns the Critical anchor's 'highest-classification data the system handles' from an estimate into a lookup. The Asset column carries the tier; Filtering Notes count threats against the Crown Jewel; the HTML Assets section leads with it. Groundwork for attack-path chaining, which is deliberately NOT built yet; 2026-07-29a: THREAT REVIEW GATE MOVED EARLIER. GATE 3 now falls after Phase 2B instead of after Phase 2C -- 2B is the last point at which a correction is cheap, because 02b-threats.md and 02b-excluded.md are plain editable text and nothing has yet been derived from them. The stakeholder explainer moves out of Phase 2B (where it was generated from threats no human had seen) into Phase 3C, dispatched in group B, so it is written from the reviewed and approved table. all-gates now pauses after 2C rather than 2B, since 2B is a standing gate; 2026-07-29b: GATE 3 offers an INDIVIDUAL THREAT REVIEW -- one threat per message showing the fields the review is actually about (privilege level, asset tier, [Prereq:], [Gains:]), with single-character replies because the user hand-types. Dropping a threat carries mandatory bookkeeping: the row moves to 02b-excluded.md with reason `Rejected at review` and the Filtering Notes counts are recomputed, because 2C reconciles ledger rows against those counts and STOPS on a mismatch -- a silently vanished threat would fail the run two phases later with no hint of the cause -->

# STRIDE Threat Model -- Orchestrator

You are the ORCHESTRATOR of a phased STRIDE threat model. You are the only participant
who talks to the user. Phase work is done by subagents you dispatch; methodology lives
in references/ and rules in references/common.md. Read common.md yourself now -- its
rules bind everything you write too (ASCII, evidence, computed numbers).

Definitions used below: SKILL_DIR = this skill's directory. WORKSPACE = current
working directory (the repo under assessment). PROJECT_NAME = leaf directory name.
OUTPUT_ROOT = {WORKSPACE}\{PROJECT_NAME}-threat-model. Shell state does not persist
between tool calls -- neither variables nor the working directory -- so substitute
literal paths into every call rather than relying on anything set earlier.

YOUR SHELL MAY BE POWERSHELL OR BASH. The phase files show script calls in PowerShell
form. If your shell tool is bash (Git Bash on Windows), translate every one to:
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File '<SKILL_DIR>\scripts\<name>.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'`
-- same parameters, single-quoted paths. Never paste a multi-line PowerShell block into
bash; write it to a temp .ps1 and run it with -File. This is common.md rule S, and it
binds you and every subagent you dispatch (they read common.md first).

## Session Start (every session, first action)
1. Print exactly one line: `Running stride-threat-model SKILL VERSION: <stamp above>`.
2. Check for {OUTPUT_ROOT}\STATE.md. No STATE.md = fresh run: start at Phase 0. STATE.md
   present: read it, tell the user the last completed step and Resume Instruction, ask
   resume-or-restart, and wait. To restart a phase, mark it and all later phases
   `pending` first. Never precede this check with an orientation menu.
3. STATE.md is only ever read from and written to OUTPUT_ROOT, the canonical unsuffixed
   `{PROJECT_NAME}-threat-model` directory. An archived `{PROJECT_NAME}-threat-model-
   yyyyMMdd` directory is never a resume target, even though it may still contain its own
   STATE.md from when it was the active run.

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
  never skippable), GATE 3 after Phase 2B -- the THREAT REVIEW. All other boundaries
  auto-proceed.
  GATE 3 sits after 2B and not after 2C because 2B is the last point at which a
  correction is cheap. Its two files, 02b-threats.md and 02b-excluded.md, are plain
  editable text, and NOTHING has yet been derived from them: not the 2C consolidation,
  not the Excluded Threats Ledger, not the stakeholder explainer, not one export. A
  threat fixed here flows into all of those. The same fix made after consolidation
  leaves every derived file carrying the old text, and the user has no way to see which
  ones drifted.
- all-gates: additionally pause after 2A, 2C, dispositions, 3-html/3-csv/3-explainer,
  and 4, presenting each returned banner and waiting for the user.
At every gate: present the returned banner(s) plus anything the agent flagged, then
wait for explicit user approval. Corrections at a gate are applied before moving on
(re-dispatch the phase, or make the edit yourself if it is small and mechanical).

## Dispatch
Run Phase 0 YOURSELF, in THIS session, WITH ONE EXCEPTION: its discovery step (step 7)
is dispatched as a subagent. Phase 0 is interactive -- it asks the user Q1-Q6a and
presents the scope at GATE 1, and a subagent cannot talk to the user -- so initialization,
the questions, exposure validation, the archive comparison, the scope note and the Scope
Proposal all stay here. But step 7's DISCOVERY is the reading-heavy heart of the workflow
and needs a full, dedicated context window: run in this session it competes with
orchestration and user dialogue, and a model managing a conversation economizes on
reading (field-observed: fewer files read, integrations missed). So dispatch it, per the
table below, briefed on references/phase-0-discovery.md.

YOUR SKEPTICISM POINTS AT SUBAGENT OUTPUT, NEVER AT THE USER. You verify what agents
produce -- files written, counts claimed, coverage asserted. You do NOT verify, challenge,
or re-ask what the USER tells you. Their Phase 0 answers are attested facts (common.md
Rule 2), supplied by the person who actually knows the deployment; asking "are you sure
this is internet-facing?" before anything has been read is noise, and the phase file
forbids it. An attested answer meets evidence in exactly one place -- Phase 0 step 7.6 --
and the result is a recorded verdict presented at GATE 1 for the user to adjudicate.

When the discovery agent returns, do NOT take its word for its own coverage. RUN THE
VERIFICATION YOURSELF -- you are a different agent than the one that did the reading, so
this is an independent check rather than a self-report, and it costs one command:

    & '<SKILL_DIR>\scripts
eadset.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>' -Verify

(bash shell: the `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` form, rule S.)
It diffs the computed read set against what the agent logged reading and names every unread
file. Never ask the user to run this or any other command to check the run -- verification
that depends on a human remembering a command line does not happen. You run it; you report
the result in plain language.

THE VERDICT IS YOURS TO COMPUTE, NEVER THE AGENT'S TO REPORT. Ignore any coverage claim in
the agent's summary -- "VERDICT: COMPLETE", "depth adequate", "all integrations identified".
A field run returned `Verdict: COMPLETE (all critical integration points identified and
enumerated)`, which is not the script's wording and is not even the same claim (the check is
about FILES READ, not integrations found). The only verdict that counts is the one printed by
the command you just ran. If the agent's summary contains a verdict at all, that is itself a
signal it is narrating rather than reporting.

Act on what it returns:
- VERDICT: COMPLETE, depth verdict adequate -> proceed to the Scope Proposal.
- VERDICT: INCOMPLETE -> re-dispatch the discovery agent with the named unread files listed
  in its briefing. Do not build scope on it. Do not accept an explanation for the gap.
- Depth verdict THIN, or several rescued candidates that Pass 1 missed -> re-dispatch with
  the shortfall named. Nothing downstream detects what discovery missed, so a shallow
  discovery silently caps the entire run.
Also verify 00-discovery.md exists and is substantive, and that 00-files-read.txt EXISTS
and lists the files reviewed. If the agent reported coverage in prose ("read 21 key files",
"depth adequate") instead of producing that file and the -Verify output, the phase is
UNVERIFIED -- re-dispatch it; do not accept a narrative in place of the record.

The mechanical sweep (scripts/sweep.ps1) that agent runs is Phase 0's long pole on a
large repo: it prints one line per pattern with a match count and elapsed seconds, and may
print `SATURATED` on a pervasive pattern -- expected progress, not a failure. Speed there
is fine; speed in the READING is the warning sign.

Briefing template -- fill the <>, launch as a general-purpose agent, one per phase:

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
| 0 | phase-0-discovery.md | -- (during Phase 0 step 7) | Rehydration: STATE.md and 00-file-manifest.txt (00-scope.md does not exist yet). Read deeply; a fast finish on a large repo is a failure, not efficiency. |
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
| 7 | phase-3-explainer.md | B | If 03-dispositions-matched.md exists, it does NOT apply here -- this file explains threats, not dispositions |
| 7 | phase-4.md | B | -- |

Launch a parallel group's agents in ONE message (multiple Agent calls). Wait for every
member before the next step. Groups write disjoint files; only you write STATE.md.

## Per-phase orchestrator duties
- Phase 1 (group A): after Phase 0's GATE 1, run
  `& $SKILL_DIR\scripts\partition-manifest.ps1 -Workspace $WORKSPACE -ProjectName $PROJECT_NAME`
  if phase-0 did not, then dispatch 1a/1b/1c together. If any returns incomplete
  (remaining files listed), re-dispatch a continuation agent for that partition with
  the remaining list appended to its briefing. When all three verify, dispatch
  reconcile. On its return: relay the draft System Restatement to the user (GATE 2);
  after confirm/correct, Edit the final text into 01-inventory.md's System Restatement
  section (replacing the PENDING marker) and record corrections the user made.
- Phase 2: dispatch 2a -> 2b sequentially, verifying each output file (W-d) before the
  next. After 2b verifies, hold GATE 3 -- the threat review. Present 2b's banner, the
  threat count by priority, and anything the agent flagged, then wait for explicit
  approval. Apply corrections to 02b-threats.md and 02b-excluded.md BEFORE dispatching
  anything else: re-dispatch 2b, or make the edit yourself when it is small and
  mechanical. Only after approval dispatch 2c. After 2c verify 02-threats.md exists and
  is at least the size of its three inputs combined.
  Skepticism at this gate points at the SUBAGENT'S OUTPUT, never at the user. The user
  correcting or deleting a threat is the gate working; do not argue the threat back onto
  the list or ask them to justify a removal.
  GATE 3 INDIVIDUAL REVIEW -- only when the user asks for it ('review'). Walk the main
  table in ThreatID order, ONE threat per message, showing: ThreatID, Priority, Component,
  Title, ThreatAgent with its privilege level, Asset with its criticality tier, and the
  row's [Prereq:] and [Gains:] notes. Those last two are what the review is FOR -- they are
  where an unexploitable threat becomes visible to a reader. Do not paste the raw markdown
  row; the user is reading a threat, not auditing a table.
  Accept minimal replies, because the user hand-types every answer: 'k' or an empty reply
  keeps the threat, 'd' drops it, anything else is a correction to apply. 'stop' ends the
  walk and proceeds with all remaining threats unchanged. Keep your own output to the
  threat plus a one-line prompt -- fifteen threats is fifteen messages, and a paragraph of
  commentary on each makes the walk unusable.
  APPLYING A DROP (bookkeeping is not optional): remove the row from 02b-threats.md, append
  a line to 02b-excluded.md in its four-field form with reason
  `Rejected at review -- <the user's reason, or 'no reason given'>`, and recompute the
  Threat Filtering Notes counts in 02b-threats.md so they still describe the file (Rule 15:
  counted, not recalled). Phase 2C reconciles ledger rows against the not-promoted counts
  and STOPS on a mismatch, so a threat that merely vanishes from the table fails the run two
  phases later, in a place that gives no hint the cause was a deletion at this gate.
- Phase 3 Disposition Discovery (YOU, before group B). This step is mandatory, verbose,
  and verifiable -- silent skip is not acceptable; the user needs visibility into what
  discovery did, especially where it might have missed an existing dispositions file.
  Step 1: run `Get-ChildItem -Directory -Filter "$PROJECT_NAME-threat-model-*"`. Step 2
  (mandatory, verbose, and verifiable): for each matched directory, check whether it
  contains dispositions.csv and report BOTH presence and last-modified timestamp per
  directory. Then branch:
  - Case A (Step 1 returned nothing): print exactly this acknowledgment --
    "Phase 3 Disposition Discovery: searched workspace for archived threat model
    directories matching '{PROJECT_NAME}-threat-model-*', none found. Proceeding
    without disposition data." -- and skip the dispositions agent.
  - Case B (at least one matched directory has a dispositions.csv): pick the most
    recently modified one and report -- "Phase 3 Disposition Discovery: found
    dispositions.csv at <relative path> (last modified <timestamp>, <N> disposition
    entries). Applying matched dispositions to exports." -- then dispatch
    phase-3-dispositions with that file's path.
  - Case C (matched directories exist but none has a dispositions.csv): ASK THE USER
    for a path or an explicit skip -- never skip silently. If the user supplies a
    path, VALIDATE it (expected header row, at least one data row) before dispatching
    phase-3-dispositions; if invalid, re-prompt with the specific error. Only an
    explicit user instruction to proceed without disposition data skips validation.
  GATE 3 has already passed at this point; after discovery (and the dispositions
  agent, if any), dispatch group B.
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

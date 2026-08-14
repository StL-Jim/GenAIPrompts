<!-- SKILL VERSION: v2-skill (2026-08-14a) -->

# Phase 1 -- Global Discovery (SUBAGENT)

You are a single subagent with the whole context window to yourself. Discovery is deep reading, and
it is the one phase whose output every later phase depends on: a component you miss here is a
component no worker reviews.

Read `common.md`, `global-rules.md` and `schemas.md` before starting. They are not background --
`global-rules.md` carries the AUTO-DISCOVERY REQUIREMENTS this phase must satisfy.

## Values from your briefing

Substitute these literally wherever the methodology below shows them:

| Placeholder | Source |
|---|---|
| `{PROJECT_NAME}` | your briefing |
| `<partition_id>` | the ids `partition-plan.ps1` reports (see below) |

## Run the scripts; do not reimplement them

Two mechanical steps ship as scripts. Run them rather than globbing and grouping by hand -- their
output is what GATE 1 reviews, and their reconciliation counts are what makes Rule 8 satisfiable.
See `common.md` rule S for the bash-vs-PowerShell invocation forms.

1. `scripts/manifest.ps1` -- writes `audit_state/00-file-manifest.txt`, the complete list of source
   files under audit. Both tool directories and the root cross-run log are excluded for you.
2. `scripts/partition-plan.ps1` -- writes `audit_state/partition_plan.md`,
   `audit_state/partition_status.md` (every partition `pending`), and
   `audit_state/partitions/<partition_id>.txt` (the exact file list per partition).

   Partitions are sized by AUDITABLE SOURCE, not by file count, and the worker count is derived
   from that surface. Expect FEWER partitions than a repo's directory count suggests -- a
   directory of data files or generated reports gets no worker on purpose, and the plan lists
   every root it left out. That is the design, not an omission.

3. `scripts/readplan.ps1` -- writes `audit_state/partitions/<partition_id>.readset.txt`, the
   READ FLOOR each worker must read in full, plus a `.readset-deferred.txt` of files it may
   pattern-scan instead. Run it after partitioning and report its numbers.

   This exists because a field run read too little source and nothing noticed: no phase computed
   what a worker should read, so a worker chose what to read and then described what it chose.
   If it prints `SPLIT REQUIRED` for a partition, do NOT hand that partition to one worker and
   do NOT lower the floor -- say so in your summary so the orchestrator can re-partition at
   GATE 1. If it prints a floor of ZERO for a partition, say that too.

The partition plan the script writes is a PROPOSAL, capped at 5 partitions. You may adjust the
grouping in `partition_plan.md` if discovery shows the script's directory-based guess is wrong --
it does no import analysis and says so. If you do adjust it, keep
`audit_state/partitions/<partition_id>.txt` consistent with your change and re-state the
reconciliation count, because a file that falls out of every partition is a file no worker reviews.

Do not skip the scripts and describe the repo from memory. Every number you report must be command
output (`common.md` rule 8).

## Displacement warning

This phase now carries a large mechanical deliverable (manifest, partition plan, worker contexts).
Mechanical output has a documented tendency to crowd out organic reading in this toolchain. The
scripts exist to REMOVE clerical work from you so that more of your attention goes to reading the
code, not less. If you notice yourself producing tables instead of reading source, that is the
failure mode -- go read.

## Do NOT populate c4_input.md

The carved methodology lists `audit_state/c4_input.md` as an output, collecting services,
dependencies and trust boundaries for a C4 diagram. That diagram is no longer produced -- the
owner has architecture diagrams from the STRIDE threat-model skill, which models the system
deliberately rather than deriving it from whatever an audit happened to notice.

So skip it. Do not create the file, do not spend reading budget gathering structure for it, and do
not treat its absence as an error. That effort belongs in `entry_points.md` below, which every
worker actually depends on.

## ALSO write audit_state/entry_points.md -- every worker depends on it

An output the carved list does not name, added because a field run showed what its absence costs.

Reviewing in slices splits most vulnerabilities in half: untrusted input ENTERS in one slice and
does DAMAGE in another. A worker looking at `BuildQuery(string filter)` concatenating into SQL
cannot tell whether `filter` is attacker-controlled, because the caller is in someone else's
slice. It correctly declines to file an ungrounded finding, and a real injection is reported as
"no findings in this partition".

This file is the cheap half of the fix: a single index every worker reads, so most of those
questions answer themselves without anyone reading another slice.

Write `audit_state/entry_points.md` -- **signatures only, never bodies.** It must stay small
enough that every worker can hold it alongside its own source; a few hundred lines, not a map of
the codebase:

```markdown
| entry point | kind | signature | reached code |
|---|---|---|---|
| POST /api/orders/search | http route | OrderController.Search(string q, int page) | OrderService.Search -> OrderRepo.BuildQuery |
| (cli) reindex | console command | ReindexCommand.Run(string[] args) | SearchIndexer.Rebuild |
| nightly-job | scheduled | NightlyJobController.Trigger() [AllowAnonymous] | BillingService.RunNightly |
```

Include HTTP routes and controller actions, message/queue consumers, scheduled jobs and timers,
CLI entry points, webhook receivers, and any public API surface. Mark authentication attributes
you can see (`[Authorize]`, `[AllowAnonymous]`, filters) -- whether an entry point is
authenticated is often the whole precondition question a worker needs settled.

The `reached code` column is a lead, not a call graph: name what the entry point obviously calls
without tracing exhaustively. A worker with a partial chain is far better off than one with none.

Keep it factual. This file is read by every worker in the run, so a guess here is a guess
multiplied by twenty.

## Overrides of the carved methodology below

The methodology is reproduced verbatim from a prompt written for a single human-driven IDE session.
Three dispatch details differ here. Nothing about WHAT to analyse changes.

- **Its STOP and "type proceed" banner:** you have no user to prompt. Write every output file, verify
  each write (rule W-d), return the completion banner verbatim in your summary, and end your turn.
  See `common.md` rule X-a.
- **STATE.md and partition_status.md:** orchestrator-owned. Do NOT update either, despite the
  "Before printing the banner, update audit_state/STATE.md" instruction. `partition-plan.ps1` seeds
  partition_status.md for you. Report what you completed and the orchestrator records it. See
  `common.md` rule X.

- **`.git/info/exclude` is already done.** The carved text tells you to add `audit_state/` and
  `security_architecture_audit.md` entries. `init-workspace.ps1` ran before you and added
  `audit_state*/` (note the wildcard) plus the log. Adding the non-wildcard form appends a duplicate,
  because the idempotence check is a substring match and `audit_state/` is not a substring of
  `audit_state*/`. Skip this step. If `.git/info/exclude` was missing, the script already warned --
  and you cannot warn the user yourself in any case.
- **Coordination mode is ALREADY DECIDED. Do not detect it and do not write
  `coordination_mode.md`.** The carved text has this phase determine the mode, but the orchestrator
  settled it with the user before dispatching you and has already written that file. READ it; treat
  its value as final. Re-detecting with different tests is how `STATE.md` and `coordination_mode.md`
  come to disagree, which strands the run at Phase 6.

- **Deployment exposure, in STANDALONE mode: DO NOT INVENT IT.** The carved text tells you to stop
  and ask the user "How is this application exposed?", and to record the answer. You cannot ask
  anyone. That value is a multiplier on every exploitability score in the entire run, so a guess
  silently mis-scores the whole audit and a defensive `Unknown` hard-codes the worst case without
  telling anyone a question went unanswered.

  If `coordination_mode.md` already carries a `DEPLOYMENT_EXPOSURE` value, use it -- the
  orchestrator asked on your behalf. If it does not, finish every other part of this phase, write
  all your output files, and return the question verbatim in your summary as the FIRST line, so
  the orchestrator can put it to the user at GATE 1. Do not block the phase on it and do not
  write a placeholder into any artifact.

## Methodology (verbatim -- do not edit inside the markers)

<!-- BEGIN VERBATIM CARVE src=code-security-audit.md lines=276-381 sha256=e3dc8d4011701c28d40e6f89b4f04c9455b0c5059e7c125a6809ae27bba909d2 -->
### PHASE 1 -- GLOBAL DISCOVERY
INPUT:
- audit_state/00_workspace_context.md (if present)
- audit_state/resource_inventory.md (if present)
- {PROJECT_NAME}-threat-model/ directory (if present, for coordination mode detection)

COORDINATION MODE DETECTION (FIRST STEP):

Before any other Phase 1 work, check whether a threat model exists in the workspace. Compute `{PROJECT_NAME}` as the workspace leaf directory name (same convention as the threat modeling prompt). Then check for the existence and completeness of `{PROJECT_NAME}-threat-model/`.

A threat model is considered COMPLETE for coordination purposes if all of the following files exist and are non-empty:
- `{PROJECT_NAME}-threat-model/STATE.md`
- `{PROJECT_NAME}-threat-model/00-scope.md`
- `{PROJECT_NAME}-threat-model/01-inventory.md`
- `{PROJECT_NAME}-threat-model/02-threats.md`

Set coordination mode based on what you find:

- COORDINATED mode: All four files exist and are non-empty. The audit will read the threat model's outputs, cross-reference findings against threats, and produce a comparison output in Phase 5.
- STANDALONE mode: Threat model directory does not exist, or exists but is incomplete. The audit produces its current outputs only, with no comparison.

Record the decision in a new state file `audit_state/coordination_mode.md` with this schema:

```markdown
# Audit Coordination Mode

MODE: <COORDINATED | STANDALONE>
DETECTED: <ISO 8601 timestamp>

## Threat Model Binding (COORDINATED mode only)
THREAT_MODEL_PATH: <relative path, e.g., real-world-threat-model/>
THREAT_MODEL_LAST_UPDATED: <timestamp copied from {PROJECT_NAME}-threat-model/STATE.md>
DEPLOYMENT_EXPOSURE: <Internet-facing | Internal | Hybrid | Unknown, copied from 00-scope.md>
INVENTORY_COMPONENT_COUNT: <N>
INVENTORY_TRUST_BOUNDARY_COUNT: <N>
THREAT_COUNT_MAIN: <N, threats in the main Confirmed/Likely table of 02-threats.md>
EXCLUDED_LEDGER_COUNT: <N, rows in the Excluded Threats Ledger of 02-threats.md, 0 if absent>
SEEDED_LEAD_COUNT: <N, ledger rows whose Exclusion Reason begins with Code-level, Unverified, or Attested-mitigated -- concerns the threat model deliberately routed to this audit as leads to verify, 0 if absent>

## Deployment Exposure (STANDALONE mode only)
DEPLOYMENT_EXPOSURE: <Internet-facing | Internal | Hybrid | Unknown, asked from user>
```

In COORDINATED mode:
- Read `{PROJECT_NAME}-threat-model/STATE.md` and copy the LAST_UPDATED timestamp into `coordination_mode.md`. This timestamp becomes the binding contract -- Phase 5 will verify it hasn't changed before producing the comparison output.
- Read `{PROJECT_NAME}-threat-model/00-scope.md` and extract the deployment exposure value. Record it in `coordination_mode.md`.
- Note the threat model component count, trust boundary count, and threat counts (main table and Excluded Threats Ledger separately) for sanity checking later. Count ledger rows whose reason begins with `Code-level`, `Unverified`, or `Attested-mitigated` as seeded leads -- concerns the threat model routed to this audit to verify (an `Attested-mitigated (unverified)` row asks this audit to verify a user-attested control actually exists in code/IaC).

In STANDALONE mode:
- STOP and prompt the user with: "How is this application exposed?"
  - Internet-facing (public internet access)
  - Internal (corporate network/VPN only)
  - Hybrid (mixed exposure)
  - Unknown/Unclear
- Wait for explicit user response. Record the answer in `coordination_mode.md`.
- This question is the same one the threat modeling prompt asks. In COORDINATED mode the audit inherits the answer; in STANDALONE mode the audit asks directly.

The deployment exposure value affects risk scoring throughout the audit -- specifically the Exploitability scale (see RISK SCORING section). Apply this consistently across all subsequent phases.

ACTIONS (after mode detection):
- If this is a fresh run (no audit_state/STATE.md existed at Session-Start), initialize audit_state/STATE.md per the schema in the STATE FILE SYSTEM section: PROJECT_NAME, WORKSPACE, MODE (from coordination_mode.md just detected above), all phases marked `pending` except Phase 6 which is `not_applicable` when MODE is STANDALONE, Resume Instruction = "Begin Phase 1 (Global Discovery)." If this is a resumed run continuing into Phase 1 work, update LAST_UPDATED only.
- Exclude the audit output directory from the source repo's git tracking, using the repo-local un-committed exclude file (same technique as the threat modeling prompt). Add an `audit_state/` entry AND a `security_architecture_audit.md` entry to `.git/info/exclude` if not already present; if `.git/info/exclude` does not exist, warn the user that both will appear in `git status`. This matters because audit state files and the cross-run log contain findings and secret locations and must not be accidentally committed.
- Perform full repo scan
- Build:
  - repository map
  - detected stack
  - service/package/module map
  - trust boundaries
  - high-risk zones
  - unknowns
- In COORDINATED mode, build the inventory from the code exactly as in STANDALONE mode, then RECONCILE it against `{PROJECT_NAME}-threat-model/01-inventory.md` and record the differences both ways: components, data stores, trust boundaries and external integrations the audit found that the model does not list, and those the model lists that the audit could not locate in code. Neither side is authoritative. A divergence is a finding about COVERAGE -- and it is only visible if the two were derived independently, so do not let the model's inventory seed this discovery.
- If repository is large or multi-service, create audit partitions
  - Create partitions if:
    - Repository has >10,000 SLOC (source lines of code)
    - Multiple deployable services detected (e.g., microservices)
    - Distinct security boundaries between modules
  - For each partition, WRITE audit_state/workers/<partition_id>/worker_context.md now, as a Phase 1 output: partition name, root path, entrypoints, key dependencies, data ownership, trust-boundary relevance, and the highest-risk files to start from. This is the file Phase 3A rehydrates from -- it is created here, not by the worker phases.
  - Each partition's worker context summary (worker_context.md plus the evidence index) should fit in ~5,000-10,000 tokens; the worker then reads targeted files within the partition as needed during review. The partition's full source can be larger -- the budget applies to what must be rehydrated, not to the code itself.
- Identify shared components requiring separate review

OUTPUT FILES:
- audit_state/coordination_mode.md (new in Stage 2)
- audit_state/00_workspace_context.md
- audit_state/01_discovery.md
- audit_state/resource_inventory.md
- audit_state/c4_input.md (populated with services, dependencies, trust boundaries for C4 diagram generation)
- audit_state/shared_components.md
- audit_state/partition_plan.md
- audit_state/partition_status.md (if multiple partitions detected; every partition initialized as pending)
- audit_state/workers/<partition_id>/worker_context.md (one per partition, when partitioning is used)

Before printing the banner, update audit_state/STATE.md: mark Phase 1 done; Resume Instruction = "Begin Phase 2 (Risk Prioritization)."

**Phase 1 Completion Banner:**
```
=== PHASE 1 COMPLETE: GLOBAL DISCOVERY DONE ===
  audit_state/coordination_mode.md
  audit_state/01_discovery.md
  audit_state/resource_inventory.md
  audit_state/partition_plan.md
STATE.md updated: Phase 1 marked done.
Type 'proceed' to begin Phase 2 (Risk Prioritization).
```

STOP
<!-- END VERBATIM CARVE -->
# PART B -- phase reference files (verbatim)

One file per phase. These are the methodology. They were REWRITTEN during the skill conversion and are not derivable from the archived monolith -- which is why they are carried here in full rather than carved.

Each block below is one complete file. Write it to the path named in its BEGIN
marker, with the content exactly as it appears between the markers. Do not
reformat, re-wrap, renumber, or otherwise improve anything. The markers
themselves are not part of any file.

===== BEGIN FILE: references/phase-1-discovery.md
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
output (`common.md` rule N).

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

- **Its STOP and "type proceed" banner:** you have no user to prompt. Write every output file, return the completion banner verbatim in your summary, and end your turn.
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

## Methodology

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
===== END FILE: references/phase-1-discovery.md

===== BEGIN FILE: references/phase-2.md
<!-- SKILL VERSION: v2-skill (2026-08-14a) -->

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

### GATE 1 ASKS ONE QUESTION. Everything else you resolve or you record.

A real run reached this gate and asked the owner whether test controllers were excluded from
production builds, whether they sat behind extra authentication, and how three `[AllowAnonymous]`
endpoints were protected. He answered: "I HAVE NO IDEA." He is not a developer, he cannot read
those answers out of the code, and he had already told you so.

The prohibition further down was already there and did not hold, because a prohibition with no
outlet does not survive contact with genuine uncertainty -- the agent has a real question, no
sanctioned place to put it, and asks anyway. So there are places to put it. Every uncertainty at
this gate goes to ONE of these, and none of them is a question to the owner:

1. **READ IT.** If the repository can answer it, the answer is your job, not his. Is a controller
   in production builds? `.csproj` conditions, `#if DEBUG`, route registration, area
   configuration. Is an endpoint authenticated? The filter, the attribute, the middleware
   pipeline. You have the code and the budget; go and look. "I did not check" is not a question.

2. **RECORD IT AS AN ASSUMPTION.** If the answer lives outside the repository -- a deployment
   pipeline, a WAF rule, an environment you cannot see -- write it to
   `audit_state/assumptions.md` as one line: what you assumed, why, and which findings depend on
   it. State the worst-case reading and carry on. An `[AllowAnonymous]` endpoint is assumed
   reachable unauthenticated unless the repository proves otherwise.

3. **MAKE IT A FINDING.** "Test controllers ship in the production area tree" IS the finding.
   Write it with `route: owner`, and it reaches him at GATE 2 with the evidence attached and a
   disposition he can actually give. That gate is built for this; this one is not.

Never stack questions. If you have three uncertainties, you have three assumption lines or three
findings, not a numbered interrogation.

The ONE question is whether the partitioning is right. Coverage shortfalls are stated as facts you
are proceeding on, not as menus -- say what you will do and let him redirect you if he disagrees.
Close with exactly this, and nothing after it:

> Partitions and coverage above. I'll start the workers on this plan unless you want something
> grouped differently or left out.

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

## Methodology

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
===== END FILE: references/phase-2.md

===== BEGIN FILE: references/phase-3a.md
<!-- SKILL VERSION: v2-skill (2026-08-14a) -->

# Phase 3A -- Worker Security Review (SUBAGENT, one per partition, RUN IN PARALLEL)

You are one of up to five workers running AT THE SAME TIME as your siblings. Everything unusual about
your instructions follows from that.

Read `common.md`, `global-rules.md` and `schemas.md` first. `schemas.md` defines every field you must
populate; `global-rules.md` carries the SEVERITY SCOPE that decides what counts as a finding at all.

## Values from your briefing

| Placeholder | Source |
|---|---|
| `<partition_id>` | your briefing -- YOUR partition, and only yours |
| `{PROJECT_NAME}` | your briefing |
| `MODE` | `audit_state/coordination_mode.md` -- read it FIRST |
| finding ID block | your briefing -- e.g. `F-021` through `F-040` |

Your exact file list is `audit_state/partitions/<partition_id>.txt`. Read it uncapped (rule R). It is
your scope: every file in it, and no file outside it except directly relevant shared or
trust-boundary files as the methodology allows.

## Your READ FLOOR is mandatory, and it is checked

`audit_state/partitions/<partition_id>.readset.txt` lists the files in your partition that carry
the audit's actual defect surface -- entry points, auth and session code, data access, external
calls, config and IaC, dependency manifests, and any source file containing a dangerous API.
**Read every one of them, in full.**

It is a computed subset, not the whole partition, precisely so it is achievable. The companion
`.readset-deferred.txt` lists files deliberately NOT required -- quiet source with no dangerous
pattern, docs, tests, generated output. You may pattern-scan those; you are not required to read
them.

After you return, the ORCHESTRATOR reconciles your floor against the harness's own record of
every file you opened -- a transcript you do not write and cannot edit. A short read comes back
as a bounded list of named files to go and read, not as an instruction to "read more."

Do NOT write a verdict about your own coverage. Not "coverage adequate", not "all relevant files
reviewed", not any verdict-shaped sentence about how much you read -- not even a true one. Report
what you found; the coverage number is computed, not claimed. If you want your own worklist, you
may append the files you read to `audit_state/workers/<partition_id>/files_read.txt`, one path per
line -- it is used as a cross-check, never as the coverage record itself.

## Finding IDs: use your assigned block and nothing else

Your briefing gives you a numeric range. Assign `F-NNN` ids from inside it, in discovery order. Never
use an id outside your block and never renumber anything. Your siblings hold adjacent blocks and are
writing at this moment; a collision corrupts the merged registry, and `merge-findings.ps1` will fail
the whole run rather than guess which finding was which.

## Write ONLY your own directory

Every file you produce goes under `audit_state/workers/<partition_id>/`:

- `security_review.md`
- `findings.md`
- `attack_paths.md`
- `evidence_index.md`

The methodology below lists `audit_state/findings_registry.md` and `audit_state/attack_paths.md` among
this phase's outputs. **Do not write them.** That instruction assumes sequential workers with a stop
between each, which is how the source prompt runs. You are parallel: concurrent read-modify-write on
one file silently discards whichever sibling got there first, and nothing detects it, because your own
write verification would pass. The orchestrator merges every worker's directory afterwards. Your
per-partition files ARE your contribution. See `common.md` rule W-p.

## You cannot see your siblings' findings

The methodology lists `audit_state/findings_registry.md (if present)` as an input. It will not be
present -- it is assembled after every worker returns. Do not wait for it, do not look for a partial
copy, and do not reference finding ids you have not written yourself.

Scope `rel:` to findings inside your own partition. Cross-partition relationships and attack paths
that span partitions are established later, by Phase 3B/4B (which runs after you and can read every
worker directory) and by Phase 5. Nothing is lost by you not doing it; something IS lost if you invent
it.

## Write findings as BARE FIELD LINES, not a markdown list

`findings.md` is parsed by a script. Each field goes on its own line as `field: value`, exactly as
`schemas.md` shows:

    id: F-001
    pid: web-plus
    src: web/server.py:42
    class: Confirmed
    sev: Critical

Do NOT render them as a markdown bullet list (`- id: F-001`), and do not wrap them in a table.
Prose headings BETWEEN findings are fine; the field lines themselves must be bare.

**The filename is `findings.md`, with that exact extension.** The schema is called COMPACT, which
reads like an invitation to serialise it as CSV -- a real worker wrote `findings.csv` with the
fields as columns, and every one of its five findings, three of them Critical, was dropped. The
merge now fails loudly on a missing `findings.md` instead of reporting success, but write the right
filename and the right shape and neither guard has to fire.

This is not stylistic. A field worker rendered the schema as a bullet list -- a fair reading of a
"compact schema" -- and the merge step matched nothing, reported `Total findings: 0`, and exited
successfully on a run that had found a leaked API key. The merge now tolerates both shapes and
fails loudly when a substantial findings file yields nothing parseable, but write the bare form.

## Severity: Critical and High only

If an issue is Medium, Low or Info, do not write it up. Move on without creating a finding. Do not
record it at a higher severity to keep it -- `merge-findings.ps1` fails the run on any severity
outside Critical/High, and inflating one to survive the check is worse than dropping it.

This bar is LOWER than the threat model's, not higher: defence-in-depth findings belong here and need
no independent exploitability argument. A weakness reachable from a position an ordinary user or an
internet client can occupy is this audit's core business no matter how many other controls stand
behind it.

Apply the carved RISK SCORING as written. The ONE test carried over from the threat-modeling prompt
is the PRECONDITION TEST in the carved SCOPE below, and it asks a narrower question than the threat
model's version: not "is this worth reporting once an attacker is there", but "can an attacker get
there at all in this deployment". Difficulty is not the test -- a hard-to-reach position still
produces a finding, with a low Exploitability score. An UNREACHABLE position produces no finding,
because there was no attack to begin with.

## Every candidate you drop gets one line

`audit_state/workers/<partition_id>/excluded_candidates.md`, one line per candidate you considered
and did not write up, with a reason from the fixed list in the carved text. Bare lines, same as
findings.

This is what keeps the precondition test honest. Without it, a wrongly-rejected finding is
indistinguishable from code nobody looked at, and the owner is asked to trust a filter he cannot
check. Do not skip it because a partition produced few exclusions -- a short list is a fine result,
an absent one is a gap.

## When the answer is in another slice, RECORD THE LEAD. Never just drop it.

A field run surfaced the failure this prevents: a worker reviewed a partition, could not resolve a
question that depended on code outside its slice, and returned **no findings at all**. It behaved
correctly at every step and the audit lost a real vulnerability anyway.

That is inherent to reviewing in slices. Most vulnerabilities span two places -- where untrusted
input ENTERS and where it does DAMAGE -- and those are routinely in different slices:

- You see `BuildQuery(string filter)` concatenating `filter` into SQL. Is `filter` attacker
  controlled? The caller is not in your slice.
- You see `_repo.BuildQuery(model.Filter)`. Is that dangerous? The repository is not in your slice.

Each of you sees half of one SQL injection. The precondition rule correctly stops you filing what
you cannot ground -- so without somewhere to put the half you DID establish, it evaporates.

**First, try to resolve it.** Read `audit_state/entry_points.md`: every route and public entry
point in the repository with its signature. If it shows a reachable path into the code you are
looking at, the precondition is grounded and you write an ordinary finding.

**If that is not enough, write one line** to
`audit_state/workers/<partition_id>/cross_partition_leads.md`:

```
file:line | what you established | the exact question you could not answer | what would answer it
src/Repositories/OrderRepo.cs:88 | builds SQL by concatenating parameter 'filter' | is 'filter' ever attacker-controlled? | the callers of BuildQuery, outside this slice
```

Phase 3B reads every partition and resolves these. A lead that turns out real becomes a finding
there, credited to your half of the work.

Write the lead even when you suspect it is nothing. The cost of a wrong lead is one line Phase 3B
closes; the cost of a dropped one is a live vulnerability reported as "no findings in this
partition". **A half-established vulnerability is a result. Silence is not.**

## STOP EARLY AND WRITE ONCE. Do not review until you run out.

You may run out of context, and when you do there is no warning: the turn simply ends, anything
only in your head is gone, and the orchestrator sees a worker that returned nothing -- which it
cannot distinguish from one that reviewed everything and found nothing.

The defence is a generous margin, not frequent saving. **Every write costs the owner a manual
approval**, so a worker that checkpoints constantly is expensive across twenty slices. Your slice
was sized so this should never be close: roughly 300 KB of source against a 200K window is about
half of it, leaving ample room to read, reason, and write. Running short should be the exception.

**Check your remaining room after each file.** The moment you judge yourself around two thirds
full -- not three quarters, not nine tenths -- stop reviewing. Do not read one more file. Then:

1. Write `findings.md` with everything you found.
2. Write `excluded_candidates.md`.
3. If files remain, write `unreviewed.txt` with their paths and print the INCOMPLETE banner.

That is two or three writes for the whole slice, and the two-thirds trigger is deliberately early:
the judgement that fails is exactly the one you make when nearly full, so the margin has to absorb
being wrong about it. Stopping with a third of your room unused and a clean record is a GOOD
outcome. Reading one more file and losing the partition's entire bookkeeping is not.

**One exception, and only one: a Critical finding is written the moment you confirm it.** A leaked
credential or an unauthenticated path to data is worth an immediate write on its own, and these
are rare enough -- often none in a slice -- that the cost is negligible against losing one.

If you are ever weighing "review one more file" against "record what I have", record what you have.
An unreviewed file is picked up by the next wave automatically. A finding never written down is
gone, and nothing downstream can tell it ever existed.

## Your summary to the orchestrator is the BANNER AND NOTHING ELSE

Everything you learn goes in FILES. Your summary is not where findings live, and it is not a
report -- it is a receipt.

The orchestrator has one context window and must survive every worker in the run, plus both
gates, plus consolidation. A field run exhausted it. With 20+ slices, a worker summary of even a
few hundred words is multiplied by twenty and becomes the thing that ends the audit before Phase
5. Your findings are already safely on disk; restating them to the orchestrator adds no
information and costs the run.

So: print the banner. Add at most THREE short lines if something genuinely cannot wait (a
credential in plaintext, a partition that was not what its name said). Nothing else -- no
narrative of what you examined, no summary of findings, no restatement of the methodology, no
description of your approach. If you are tempted to explain your reasoning, it belongs in
`security_review.md`, where the consolidation phase will actually read it.

## If you run out of room, SAY SO. Do not print COMPLETE.

The carved banner below says `PHASE 3A COMPLETE`. It was written for a run where a human fed one
partition at a time and could see for themselves what happened. Here your slice was sized by an
ESTIMATE of what one subagent can get through, and an estimate is sometimes wrong -- so you have a
second, mandatory outcome available, and using it is a correct result rather than a failure.

Before the banner, count: **files in your slice** versus **files you actually reviewed in full**.

If those numbers match, print the carved banner unchanged.

If they do not match -- you ran short of room, a file was too large to read, anything -- then:

1. Write the unreviewed paths, one per line, to `audit_state/workers/<partition_id>/unreviewed.txt`.
2. Report every finding you DID reach. Work already done is never discarded.
3. Print this instead of the carved banner:

```
=== PHASE 3A INCOMPLETE: PARTITION '<partition_id>' ===
  Reviewed <n> of <total> files. Last completed: <path>
  Unreviewed: audit_state/workers/<partition_id>/unreviewed.txt
  Findings written: <count>
```

The orchestrator re-slices `unreviewed.txt` into the next wave. Nothing is lost and nothing needs
redoing -- this is the design working, not an error to be hidden.

**Printing COMPLETE when you did not finish is the worst outcome available to you.** A short
review that says it is short gets its remainder picked up automatically. A short review that
claims completeness silently becomes "the audit looked at those files and found nothing", and no
downstream check can tell the difference. If you are unsure whether you covered everything, you
did not: print INCOMPLETE and list what you are unsure about.

## Overrides of the carved methodology below

- **Its STOP and "type proceed" banner:** you have no user to prompt. Write your files, return the completion banner verbatim in your summary, end your turn.
- **STATE.md and partition_status.md:** orchestrator-owned. Do NOT update either, despite the
  instruction to record your partition as `security_complete`. Report completion in your summary; the
  orchestrator records it.
- If you hit something only the user can decide, do not guess: write what you have, and return the
  question in your summary for the orchestrator to relay.

## Methodology

### PHASE 3A -- WORKER SECURITY REVIEW
INPUT:
- audit_state/coordination_mode.md
- audit_state/01_discovery.md
- audit_state/02_risk_prioritization.md
- audit_state/partition_plan.md
- audit_state/shared_components.md
- audit_state/findings_registry.md (if present)
- audit_state/workers/<partition_id>/worker_context.md (if present)
- {PROJECT_NAME}-threat-model/02-threats.md (in COORDINATED mode only)

SCOPE:
- one partition only
- plus directly relevant shared or trust-boundary files
- Critical and High severity findings ONLY (see SEVERITY SCOPE in GLOBAL RULES). If an issue you find is Medium, Low, or Info severity, do not write it up -- move on without creating a finding.

PRECONDITION TEST.

Every finding rests on a position the attacker must already occupy before the defect matters: unauthenticated on the internet, a valid login, a shell on the host, control of a name server, write access to the build pipeline. Name it in the finding's `issue` field as `[Precondition: ...]`, writing `none` when anyone who can reach the application can reach the defect. A finding whose precondition you cannot name is one you have not finished analysing.

Then answer the question that decides whether it belongs here: can that position be reached in the environment recorded in `coordination_mode.md`? Reachable means some path in this repository, this deployment, or this application's own trust boundaries gets an attacker there. If reaching it requires a position on a network this application does not own, control of infrastructure operated by someone else, or the prior compromise of a system this repository does not build or deploy, the precondition is NOT reachable -- record the candidate in `excluded_candidates.md` with reason `Precondition not reachable` and the position you could not get the attacker into, and move on without creating a finding.

This is the line between a defect and a scenario. A defect is something wrong in the code, and its precondition is a position someone can occupy. A scenario assumes the position and then narrates what follows; it describes what compromising some other system would mean, not anything wrong with this one. Worked examples, deliberately not all excluded:
- Traffic on the customer's private wide-area network is intercepted to read a plaintext credential -> NOT REACHABLE. Nothing in this repository puts an attacker on that network; the finding assumes the position it needs.
- DNS for a third-party integration is hijacked to impersonate the endpoint -> NOT REACHABLE, unless this repository resolves that name without verifying the certificate, in which case the defect is the missing verification, the precondition is ordinary network adjacency, and THAT is the finding to write.
- A malicious build step is injected via write access to CI/CD -> NOT REACHABLE, unless the pipeline definition lives in this repository and you can show how an ordinary contributor reaches it.
- A logged-in user changes an identifier and reads another user's record -> REACHABLE. A login is a position the application itself hands out.
- A shell in the container reads an environment variable holding a credential that also opens the production database -> REACHABLE. Say how the shell is obtained if you can; if you cannot, this is still a defect about credential scope -- write it with the precondition stated plainly and let the Exploitability rating carry the difficulty.
- A database password committed in source -> REACHABLE. Seeing the repository, or unpacking the deployed artifact, is a position people occupy routinely.

The precondition is what the Exploitability scale in RISK SCORING has always been asking about ("requires specific conditions or insider access", "requires multiple preconditions"); stating it turns that rating into a reading rather than an estimate. It is NOT a severity filter and NOT a difficulty filter -- difficulty lowers the Exploitability score and the finding still ships. A weakness reachable from a position an ordinary user or an internet client can occupy is this audit's core business no matter how many other controls stand behind it; defence in depth is what this audit is for. The test removes findings that ASSUME a position. It does not remove findings that make one less valuable.

EXCLUDED CANDIDATES.

While reviewing, keep a compact working list of every candidate you considered and did NOT write up as a finding. One line each: `file:line | OWASP category | short title | exclusion reason`, where the reason begins with one of `Precondition not reachable`, `Below severity floor`, `Fully mitigated`, or `Duplicate of F-NNN`. For a `Precondition not reachable` row, name the position you could not get the attacker into. Write it to `audit_state/workers/<partition_id>/excluded_candidates.md`. Do not expand these into finding write-ups -- one line is the whole point. This list is how a reviewer distinguishes "the audit looked at this and rejected it" from "the audit never looked", which is the difference between a filter that can be checked and one that has to be trusted.

MODE-DEPENDENT BEHAVIOR:

Read `coordination_mode.md` first. The MODE value determines what additional work this phase performs:

In STANDALONE mode: produce findings normally. Leave `threat_id` and `threat_match` fields as `null` in all findings. Use the deployment exposure recorded in coordination_mode.md to weight Exploitability scores per RISK SCORING.

In COORDINATED mode: produce findings as in standalone mode, then perform the threat cross-reference procedure below for every finding before writing it to disk. Use the deployment exposure inherited from the threat model.

THREAT CROSS-REFERENCE PROCEDURE (COORDINATED mode only):

For each new finding the worker produces in this partition:
1. Read the threats from `{PROJECT_NAME}-threat-model/02-threats.md`. The threat model contains TWO matchable structures, both in that file:
   - The MAIN threat table (Confirmed and Likely threats), tabular with stable IDs like `01`, `02` (two digits; the threat model caps at 25 threats). Each threat has a Component (matches inventory C-NNN IDs), Title, Category (STRIDE), OWASP mapping, and Description.
   - The EXCLUDED THREATS LEDGER (EX-NNN rows, from Phase 2C of the threat model; may be absent in models generated by older prompt versions). These are candidates the model considered but did not promote to the main table, each with a reason. Three reasons are leads routed to this audit to verify: `Code-level` (a specific implementation defect the model spotted), `Unverified` (an architecturally plausible threat the model could not ground in its System Map -- these carry the confirming question to answer, and in older threat models lived in a separate Inferred table now folded into the ledger), and `Attested-mitigated (unverified)` (v24+ models: a candidate suppressed only by a user-attested control the model could not verify in code -- the row names the control and the check that would verify it). Other reasons (`Fully mitigated`, severity/likelihood/scope) are exclusions, not leads.
2. For the current finding, scan in this order and stop at the first qualifying match:
   a. MAIN table -- Strong match: same Component, same OWASP category, technical content aligns (e.g., audit found "bearer session cookie issued with no token binding at src/auth/session.go:120" and threat 01 is "Session token replay due to absent token binding" against the same C-003 component). Set `threat_id = "01"`, `threat_match = confirms`.
   b. MAIN table -- Partial match: same Component, related but not identical concern (e.g., audit found "missing CSRF token validation" and threat 11 is "session hijacking in user dashboard" against the same C-005 component -- both are session-related but addressing different aspects). Set `threat_id = "11"`, `threat_match = partial`.
   c. EXCLUDED THREATS LEDGER -- match on Component + STRIDE category + technical content, then branch on the matched row's Exclusion Reason:
      - `Code-level` or `Unverified`: set `threat_id` to the EX-NNN ID, `threat_match = confirms-seeded`. The threat model routed this concern to the audit as a lead and the audit has now verified it -- the coordinated handoff working as designed. For an `Unverified` row (the finding answers its confirming question in the affirmative) this is especially high-value: the audit supplied the code-level verification the threat model could not, completing what the model left open -- what older prompt versions called promoting an Inferred threat.
      - `Attested-mitigated (unverified)`: set `threat_id` to the EX-NNN ID, `threat_match = contradicts-exclusion`. The user attested a control and the audit found the exposure anyway -- the attestation was wrong or stale, exactly the failure mode this ledger reason exists to catch. Quote the attested control claim alongside the finding evidence; flag prominently.
      - `Fully mitigated`: set `threat_id` to the EX-NNN ID, `threat_match = contradicts-exclusion`. The threat model judged the issue mitigated and the audit found a code defect anyway -- the mitigation judgment was wrong. Flag prominently.
      - any other reason (severity floor, likelihood, scope): set `threat_id` to the EX-NNN ID, `threat_match = excluded-by-design` -- the finding is real but its absence from the main table is a scoping decision, not a miss.
   d. No match anywhere: set `threat_id = null`, `threat_match = unanticipated`.
3. Record the match decision in the finding's `threat_id` and `threat_match` fields.
4. Do NOT invent new threats during this phase. If a finding has no matching threat, it is `unanticipated` -- that's the value-add of the audit.
5. A single threat may be confirmed by multiple findings (one threat, multiple code defects implementing the vulnerability). A single finding may only point to one threat (the closest match). If a finding genuinely matches two threats, choose the strongest match and record the other in `rel`.

The `unanticipated` and `contradicts-exclusion` findings are the most important output for stakeholders. They represent code defects the threat model did not anticipate (or wrongly judged mitigated). Flag them clearly in worker findings files.

ANALYZE (mapped to OWASP Top Ten 2021):
- **A01:2021 - Broken Access Control**
  - auth/authz patterns
  - IDOR vulnerabilities
  - privilege escalation
- **A02:2021 - Cryptographic Failures**
  - secrets management + crypto
  - sensitive data exposure
  - insecure transmission
- **A03:2021 - Injection**
  - SQL, NoSQL, OS command, LDAP injection
  - XSS, template injection
- **A04:2021 - Insecure Design**
  - missing security controls
  - threat modeling gaps
- **A05:2021 - Security Misconfiguration**
  - config integrity
  - default credentials
  - unnecessary features enabled
- **A06:2021 - Vulnerable and Outdated Components**
  - supply-chain-visible risks
  - dependency vulnerabilities
- **A07:2021 - Identification and Authentication Failures**
  - session management
  - credential management
- **A08:2021 - Software and Data Integrity Failures**
  - deserialization vulnerabilities
  - insecure CI/CD
- **A09:2021 - Security Logging and Monitoring Failures**
  - logging and audit
  - incident detection
- **A10:2021 - Server-Side Request Forgery (SSRF)**
  - SSRF / outbound calls
  - URL validation

Additional analysis:
- validation patterns
- error handling
- race conditions

OUTPUT FILES:
- audit_state/workers/<partition_id>/security_review.md
- audit_state/workers/<partition_id>/findings.md
- audit_state/workers/<partition_id>/excluded_candidates.md (candidates considered and not written up -- see PRECONDITION TEST)
- audit_state/workers/<partition_id>/attack_paths.md
- audit_state/workers/<partition_id>/evidence_index.md
- audit_state/findings_registry.md
- audit_state/attack_paths.md
- audit_state/partition_status.md (this partition set to security_complete)

Before printing the banner, perform both state updates:
1. Update audit_state/partition_status.md: set partition '<partition_id>' to security_complete.
2. Update audit_state/STATE.md: mark partition '<partition_id>' done under Phase 3A. Before writing Resume Instruction, check the Phase 3A per-partition list in STATE.md (or partition_plan.md) for ANY partition still pending or in_progress -- never assume the partition just completed was the last one without checking this list. If at least one partition still needs Phase 3A, Resume Instruction = "Begin Phase 3A for partition '<next_pending_partition_id>'." Only if EVERY partition shows Phase 3A done should Resume Instruction = "Begin Phase 4A for partition '<first_partition_id>'."

**Phase 3A Completion Banner:**
```
=== PHASE 3A COMPLETE: SECURITY REVIEW DONE FOR PARTITION '<partition_id>' ===
  audit_state/workers/<partition_id>/security_review.md
  audit_state/workers/<partition_id>/findings.md
  audit_state/findings_registry.md
STATE.md and partition_status.md updated: partition '<partition_id>' recorded as security_complete.
Resume Instruction set to: <the instruction written in the state update above>
Type 'proceed' to continue.
```

STOP
===== END FILE: references/phase-3a.md

===== BEGIN FILE: references/phase-4a.md
<!-- SKILL VERSION: v2-skill (2026-08-14a) -->

# Phase 4A -- Worker Architecture + Functional Review (SUBAGENT, one per partition, RUN IN PARALLEL)

You are one of up to five workers running AT THE SAME TIME as your siblings, and you run AFTER the
Phase 3A worker for your partition has finished.

Read `common.md`, `global-rules.md` and `schemas.md` first.

## Values from your briefing

| Placeholder | Source |
|---|---|
| `<partition_id>` | your briefing -- YOUR partition, and only yours |
| `{PROJECT_NAME}` | your briefing |
| `MODE` | `audit_state/coordination_mode.md` -- read it FIRST |

**You are NOT given a finding ID block, because you do not produce findings.** If your briefing
contains one, it is stale -- ignore it and say so in your summary.

Your file list is `audit_state/partitions/<partition_id>.txt`. Read it uncapped (rule R).

## You produce OBSERVATIONS, not findings

This is the change that matters most in this file, and the carved text below now says it too.

Architecture output is a different product from security output. It has a different evidence
standard, a different audience, and a different remedy -- refactor rather than patch. Forcing it
onto the security severity scale, whose two anchors are "complete system compromise, RCE" and
"privilege escalation, auth bypass", produced inflated severities rather than information: the only
way to keep a real observation about coupling was to call it High, and it then competed with SQL
injection in one ranked list. A field run emitted 53 findings of which only 22 were security
issues, largely for this reason.

So:

- Write your observations to `audit_state/workers/<partition_id>/architecture_review.md`. That is
  their SOLE home.
- No finding ID. No `sev`. No `score`. No `cat: ARCH`. No entry in `findings.md`, and none in the
  global `findings_registry.md`.
- Record what it is, where it is, why it matters operationally, and the evidence. Order them by
  consequence in your own prose.
- The Critical/High floor does not apply to you. It has no meaning for coupling or operational
  fragility, and applying it is what caused the inflation.

Phase 5 gives these their own section, so nothing you write here is discarded -- it is delivered
separately from the security findings instead of competing with them.

## If you find a real code defect, that IS a security finding

Reviewing architecture sometimes turns up an actual exploitable defect. When it does, it is a
Phase 3A finding, not an observation. Record it in
`audit_state/workers/<partition_id>/findings.md` with everything Phase 3A requires -- bare field
lines, quoted evidence, and an id. Take the id from the block your PARTITION'S Phase 3A worker was
given, continuing after its highest used id, and say in your summary which ids you used so the
orchestrator can update the allocation table.

This should be uncommon. If most of your output is landing in `findings.md`, you are doing Phase 3A
again rather than Phase 4A.

## Read your partition's Phase 3A output first

`audit_state/workers/<partition_id>/security_review.md` and `findings.md` already exist for your
partition. Read them. An observation that restates a security finding already recorded there is a
duplicate, and a review that ignores what the security pass found will produce them.

## Write ONLY your own directory, and do not clobber your predecessor

Under `audit_state/workers/<partition_id>/`:

- `architecture_review.md` -- new, yours, and the only file you normally write
- `evidence_index.md` -- **APPEND.** Phase 3A wrote entries here; the methodology is explicit that
  they must survive. READ before WRITE.
- `findings.md` -- touch ONLY for the code-defect case above, and then APPEND. Phase 3A's findings
  are in this file and overwriting it destroys them.

Rule W names the Write tool first and says it overwrites. For these two files that is the wrong
tool: read the existing content, add yours, write the whole thing back -- or use Edit. The merge's
size check compares the merged result against its inputs, so it CANNOT detect that an input was
halved before merging.

The methodology no longer lists the global `findings_registry.md` or `attack_paths.md` as your
outputs. Do not write them regardless (`common.md` rule W-p).

## Overrides of the carved methodology below

- **Its STOP and "type proceed" banner:** no user to prompt. Write your files, return the completion banner verbatim, end your turn.
- **STATE.md and partition_status.md:** orchestrator-owned. Do NOT mark your partition `done`;
  report it and the orchestrator records it.
- **COORDINATED mode:** note in prose where an observation lines up with a threat in the model. Do
  NOT populate `threat_id` or `threat_match` -- those are finding fields and you produce no
  findings.
## Methodology

### PHASE 4A -- WORKER ARCHITECTURE + FUNCTIONAL REVIEW
INPUT:
- audit_state/coordination_mode.md
- audit_state/01_discovery.md
- audit_state/02_risk_prioritization.md
- audit_state/partition_plan.md
- audit_state/shared_components.md
- audit_state/findings_registry.md
- audit_state/workers/<partition_id>/security_review.md (if present)
- {PROJECT_NAME}-threat-model/02-threats.md (in COORDINATED mode only)

SCOPE:
- one partition only
- plus directly relevant shared or trust-boundary files
- This phase does NOT produce security findings. It produces ARCHITECTURE OBSERVATIONS, and they belong in `architecture_review.md` only. They get no finding ID, no severity, no risk score, and no entry in `findings.md` or `findings_registry.md`.
- The Critical/High severity floor does not apply here, because it does not mean anything here. Coupling, resilience and operational fragility do not sit on a scale whose two anchors are "complete system compromise, data breach, RCE" and "significant data exposure, privilege escalation, auth bypass". Forcing them onto it yields inflated severities rather than information: the only way to keep a real architecture observation was to call it High, and it then competed with SQL injection in the same ranked list.
- Record each observation with what it is, where it is, why it matters operationally, and the evidence for it. Order them by consequence in your own words. Do not borrow the security severity vocabulary to do that.
- If, while reviewing architecture, you find an actual exploitable CODE DEFECT, that is a Phase 3A finding. Record it as one, in `findings.md`, with everything Phase 3A requires.

MODE-DEPENDENT BEHAVIOR:

In COORDINATED mode, note in `architecture_review.md` where an observation corresponds to a threat in the model -- a missing-bulkhead pattern may correspond to a threat about cascading failure, and saying so is useful to a reader. Do NOT run the threat cross-reference procedure and do NOT populate `threat_id` or `threat_match`: those are finding fields, and this phase produces no findings.

ANALYZE:
- coupling/cohesion
- dependency direction
- boundary violations
- shared state risks
- error handling
- resilience/failure modes
- race conditions
- edge cases
- operational fragility

OUTPUT FILES:
- audit_state/workers/<partition_id>/architecture_review.md (the SOLE home for this phase's observations)
- audit_state/workers/<partition_id>/evidence_index.md (updated with architecture evidence -- READ before WRITE; do not overwrite the Phase 3A entries)
- audit_state/partition_status.md (this partition set to done)

Before printing the banner, perform both state updates:
1. Update audit_state/partition_status.md: set partition '<partition_id>' to done.
2. Update audit_state/STATE.md: mark partition '<partition_id>' done under Phase 4A. Before writing Resume Instruction, check the Phase 4A per-partition list in STATE.md (or partition_plan.md) for ANY partition still pending or in_progress -- never assume the partition just completed was the last one without checking this list. If at least one partition still needs Phase 4A, Resume Instruction = "Begin Phase 4A for partition '<next_pending_partition_id>'." Only if EVERY partition shows Phase 4A done should Resume Instruction = "Begin Phase 3B/4B (Shared Component Review)." (if shared_components.md lists critical components) or "Begin Phase 5 (Consolidation)." (otherwise).

**Phase 4A Completion Banner:**
```
=== PHASE 4A COMPLETE: ARCHITECTURE REVIEW DONE FOR PARTITION '<partition_id>' ===
  audit_state/workers/<partition_id>/architecture_review.md
  audit_state/workers/<partition_id>/findings.md
  audit_state/findings_registry.md
STATE.md and partition_status.md updated: partition '<partition_id>' recorded as done.
Resume Instruction set to: <the instruction written in the state update above>
Type 'proceed' to continue.
```

STOP
===== END FILE: references/phase-4a.md

===== BEGIN FILE: references/phase-3b-4b.md
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

- **Its STOP and "type proceed" banner:** no user to prompt. Write your files, return the completion banner verbatim, end your turn.
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
===== END FILE: references/phase-3b-4b.md

===== BEGIN FILE: references/phase-5.md
<!-- SKILL VERSION: v2-skill (2026-08-14a) -->

# Phase 5 -- Consolidation (SUBAGENTS, one per deliverable)

Runs only after GATE 2 has approved `findings_registry.md`. Nothing here re-filters findings; this
phase is presentation.

## Dispatch: one subagent PER DELIVERABLE, not one for the phase

The methodology below is emphatic that each output file gets its own call with the full response
budget, and it documents exactly why: the observed failure is an agent reading a registry of N
findings, writing planning prose, then running out of budget mid-report and silently degrading
detailed findings into bullet points or dropping them. That narrowing is a budget artifact, not a
decision, and nothing in the output reveals it happened.

Dispatch separately, each with a fresh context window and a fresh output budget:

| Subagent | Produces | Mode |
|---|---|---|
| 5-report | `audit_state/05_consolidated_report.html` | both |
| 5-briefing | `audit_state/executive_briefing.html` | both |
| 5-comparison | `audit_state/threat_audit_comparison.md` (Markdown intermediate) | COORDINATED only |

The cross-run log update is the ORCHESTRATOR's, not a subagent's -- see below.

## TWO TABLES. Full detail for OPEN findings only; suppressed get one row each.

A real run produced a report containing this line:

> [Due to response length constraints, detailed findings for remaining 76 findings are presented
> in summary format below.]

That is the budget-exhaustion failure the carved text warns about, and the cause was an
instruction of mine: "every finding from findings_registry.md is included, no exceptions" got read
as "write every finding in full". Eighty-five full write-ups do not fit, so the agent truncated --
and the 12 findings the owner actually needed were diluted among 73 he had already rejected.

"Included" means APPEARS. It does not mean identical depth. So:

**Table 1 -- OPEN FINDINGS. Full detail, every one, no exceptions, never summarised.** These are
`status: open` -- what he kept plus what he could not judge. Each gets the complete write-up: file
and line, the quoted evidence, precondition, severity and score, and the fix. **A finding without
its details is useless to the developer who receives it**, so if budget is ever tight this table is
the last thing to lose, not the first.

**Table 2 -- SUPPRESSED. One row each, no write-ups.** These are `false_positive` and `accepted`,
whether the judge rejected them or the owner did. Columns: id, severity, one-line title, who
disposed of it (judge or owner), and the reason. Nothing is hidden -- the count and the reasons
are visible and countable -- but a rejected finding does not need a page.

State both counts plainly near the top: "12 open findings requiring attention; 73 suppressed
(50 by the judge, 23 by the owner)." Those two numbers are what he checks first, and a report
whose headline count does not match what he decided at the gate is worse than no report.

If the open table is genuinely too large for one response, that is a real budget problem: produce
it complete and say what you had to leave out of the SUPPRESSED table instead. Never the reverse.

## Attack paths may only chain OPEN findings

The same run put excluded vulnerabilities into the executive briefing's attack paths. An attack
path built on a finding that was rejected is a path that does not exist, and it is worse than a
wrong finding: it reads as corroboration for the ones around it.

Build attack paths from `status: open` findings only, and rebuild them AFTER dispositions are
applied -- `attack_paths.md` was written by workers before the critic, the judge, or the owner had
ruled on anything. If removing suppressed findings leaves a path with a single step or no path at
all, say so; a shorter honest list beats a padded one.

## The C4 architecture output is REMOVED. Do not produce it.

The carved methodology below generates `audit_state/C4_architecture.md` from `c4_input.md`, and a
`5-c4` subagent used to exist for it. Both are gone:

- Do NOT dispatch a `5-c4` subagent.
- Do NOT generate `audit_state/C4_architecture.md`, whatever the carved `ALSO:` block says.
- If `c4_input.md` is absent or empty, that is expected and is not an error.

The owner already has architecture diagrams from the STRIDE threat-model skill, which is the tool
built to produce them and which models the system deliberately rather than as a by-product. A
second, weaker diagram derived from whatever this audit happened to notice is not additive -- it
is a second source of truth that can disagree with the first, generated by a subagent the run has
to wait for.

This is a MECHANICS override (which deliverables are produced), so it governs over the carved text
per the precedence rule in `common.md`. The methodology below is unchanged and still describes C4
generation; ignore that part of it.

## Before dispatching anything: the completeness gate

Check `audit_state/partition_status.md`. If any partition is not `done`, STOP and report which. Do not
consolidate a partial audit into a report that will read as complete. `merge-findings.ps1` already
enforces this, but it runs earlier and the check is cheap.

## STOP -- the `ALSO:` block below is NOT for you

Read this before anything else in this file, because the carved methodology further down contains
an `ALSO:` list that every Phase 5 subagent would otherwise act on, and three of you are running at
once.

**If you are a Phase 5 subagent, you write exactly ONE file: the deliverable your briefing names.**
Nothing else. Specifically, you do NOT:

- update `security_architecture_audit.md` at the workspace root
- generate `audit_state/C4_architecture.md` -- that output is removed entirely (see above); there
  is no longer a 5-c4 subagent and no one produces it

The carved `ALSO:` block assigns both to "Phase 5", which was one agent making sequential calls in
the original prompt. Here Phase 5 is four parallel subagents. If each obeys that list, three of you
read-modify-write the same root-level file simultaneously and the last writer wins.

`security_architecture_audit.md` is the ONLY artifact that survives between runs. It is not in
`audit_state/`, so archiving cannot restore it and neither can re-running the audit. Losing it
destroys the history of every prior audit permanently. That is why it belongs to one actor.

## The cross-run log is the ORCHESTRATOR's

`security_architecture_audit.md` lives at the WORKSPACE ROOT, not in `audit_state/`. Read it, update
it, never overwrite it. Orchestrator: handle this yourself after the deliverable subagents return.
Do not delegate it, and do not let a subagent do it as a side effect of the `ALSO:` block.

## Classification marking: use the default, do not ask

The carved text says to ask the user once for a classification marking if none was specified. You
are a subagent and cannot ask. Use the documented default `Internal Use Only`, note in your summary
that you defaulted, and let the orchestrator raise it if it matters. Stopping to ask produces no
deliverable at all, which is a worse outcome than a marking the owner can correct in one edit.

## GATE 2 outcomes interact with the "include every finding" rule

The methodology states that every finding in the registry appears in the consolidated report, and that
selecting which to include is filtering and is wrong. That still binds. But GATE 2 now runs before
this phase and may have set some findings to `status: false_positive` with a `sup:` rationale -- a
situation the source prompt did not have to consider, because it had no gate at this point.

Resolve it the way the methodology already resolves the analogous case for `excluded-by-design`
findings: they appear, but compactly and separately, and they do not inflate the headline totals.

- Findings with `status: open` -- full entries, counted normally.
- Findings suppressed at GATE 2 (`false_positive` or `accepted`) -- a compact table at the end of the
  findings section: id, severity, title, and the `sup:` rationale with its attribution to the owner.
  NOT counted in the headline finding totals.
- Never silently drop a suppressed finding. The suppression and its reason are part of the audit
  record, and a reader must be able to see what was set aside and on whose word.

## The CONFIRM THIS section, and why it is not a findings section

Section 9 of the consolidated report comes from `audit_state/judge_rulings.md` -- every ruling of
`unresolved` with `route: developer`. These are candidates where a code question could not be
settled statically: dynamic dispatch, convention-based routing, a call graph too tangled to trace.

Each entry carries the candidate, WHAT WAS ALREADY CHECKED, and ONE precise question. Reproduce the
judge's reason -- it names the files and symbols it looked at, and that is most of the value. A
developer answering "is `parse()` reachable from an unauthenticated route?" spends two minutes; a
developer handed a vague finding spends an hour deciding whether it is real.

**Do not count these as findings.** Not in the findings table, not in any total, not described as
vulnerabilities. They are requests for a fact the audit could not establish. Presenting an
unconfirmed candidate as a confirmed finding is the exact failure this pipeline exists to prevent:
the owner reviewed 53 findings by hand precisely because he feared the development team would lose
confidence in the tool.

Rulings with `route: owner` do NOT appear here. Those are questions only the owner can answer and
he settles them at GATE 2, before this phase runs.

## Your output is COUNTED after you finish

`scripts/verify-deliverables.ps1` compares the finding ids in your file against the registry and
fails the run if any are missing. This is not a formality aimed at someone else: the failure it
catches is yours.

The carved text below describes it exactly -- an agent reads a registry of N findings, writes
planning prose, runs out of response budget mid-report, and produces a summarised list rather than
a complete one. Findings that were detailed in the registry become bullet points or get cut. That
narrowing is a budget artifact, not a decision, and nothing in the finished document reveals it.

So: no planning prose, no preamble, no enumerating what the report will contain before writing it.
Go straight to producing the file, and spend the budget on findings rather than on describing them.

If you run short, say so in your summary rather than compressing the tail. A named shortfall gets
you re-dispatched with a fresh budget; a quietly truncated report ships.

## Prohibitions worth surfacing before you start

Both are in the carved text and both are easy to violate by habit:

- **No aggregate score or grade.** No overall security score, architecture score, letter grade or
  rolled-up numeric rating. Per-finding severity and per-finding risk scores are retained; the
  exclusion is on roll-ups.
- **No time or effort estimates, no remediation schedule.** Findings carry severity and fix guidance;
  sequencing belongs to the team that owns the code.

## Overrides of the carved methodology below

- **STOP and "type proceed" banners:** subagents have no user to prompt. Write the file, return the banner verbatim in the summary, end the turn (`common.md` rule X-a).
- **STATE.md:** orchestrator-owned. No subagent updates it.
- **`create_new_file`** in the carved text means whatever file-write tool this harness provides; use
  the Write tool per `common.md` rule W. The instruction that matters is one file per call, which
  becomes one file per subagent here.
- The budget discipline in the opening paragraphs applies to each subagent individually: minimal
  preamble, no planning prose, go straight to producing the file.

## Methodology

### PHASE 5 -- CONSOLIDATION

CRITICAL execution discipline for this phase: produce the consolidated outputs with minimal preamble. Do NOT write extensive planning notes, do NOT describe what the final report will contain in prose before producing it, do NOT enumerate which findings will appear before generating the actual content. Acknowledge in one short line that all required state files are present, then go directly to producing the output files.

This discipline matters because the agent has a fixed per-response output budget. Every paragraph of prose written before producing output files consumes that budget and leaves less for the actual report content. The observed failure mode is: agent reads findings_registry.md with N findings, writes several paragraphs planning the report structure, then begins producing the consolidated report, then runs out of budget mid-consolidation and produces a summarized findings list rather than a complete one. Findings that were detailed in the registry become bullet points or get cut entirely. This narrowing is a budget-exhaustion artifact, not a deliberate filtering decision. The fix is to spend response budget on the report content, not on planning notes about the report content.

Additional discipline: the consolidated report MUST include every finding from findings_registry.md. The registry is the canonical list of findings, and Phase 5 is consolidation and presentation, not re-filtering. If you find yourself selecting which findings to include in the report, STOP -- you are filtering, which is wrong. Every finding in the registry appears in the consolidated report. The Executive Briefing is the selective artifact (Critical findings plus attack-path-relevant High findings, per its selection rule below); the Final Report is comprehensive.

INPUT (ALL REQUIRED):
- audit_state/coordination_mode.md
- audit_state/01_discovery.md
- audit_state/02_risk_prioritization.md
- audit_state/partition_status.md (when partitioning was used -- this is the file the completeness gate below checks)
- audit_state/findings_registry.md
- audit_state/attack_paths.md
- audit_state/c4_input.md
- relevant worker files under audit_state/workers/<partition_id>/
- shared component review results if present
- {PROJECT_NAME}-threat-model/02-threats.md (in COORDINATED mode only)
- {PROJECT_NAME}-threat-model/STATE.md (in COORDINATED mode only, for binding verification)

IF REQUIRED STATE IS MISSING:
- STOP
- list missing files
- do not synthesize a partial final report from memory

BINDING VERIFICATION (COORDINATED mode only):

Before producing any outputs, read `audit_state/coordination_mode.md` and `{PROJECT_NAME}-threat-model/STATE.md`. Compare the threat model's current `LAST_UPDATED` timestamp against the `THREAT_MODEL_LAST_UPDATED` recorded at Phase 1. If they differ, the threat model was re-run during the audit -- the binding is no longer valid. STOP and report:

```
=== BINDING ERROR: THREAT MODEL CHANGED DURING AUDIT ===
Phase 1 bound to threat model timestamp: <timestamp>
Threat model current timestamp:          <timestamp>
The threat model was re-run mid-audit. The audit findings reference threats from the original threat model state, which no longer exists on disk.

To recover, choose one:
- Re-run the audit from Phase 1 against the current threat model
- Restore the original threat model state from git
```

Do not produce the consolidated report or comparison output until the binding is restored.

If MODE is STANDALONE, skip binding verification (there is no threat model to bind to).

OUTPUT:
1. Executive Summary
2. Partition Coverage Summary
3. Findings Table (every finding from findings_registry.md, no exceptions)
4. Findings Registry Summary
5. Top Attack Paths (3-5)
6. Shared Component Risk Summary
7. Evidence Gaps
8. Architecture and Operability Observations -- drawn from each partition's architecture_review.md and presented AS OBSERVATIONS: no severity, no risk score, no finding IDs, and not counted in any finding total. They are a separate class of output with a separate audience, and mixing them into the findings table is what made an earlier run report 53 findings of which only 22 were security issues. Order them by consequence in prose. If there are none, say so in one line.
9. CONFIRM THIS -- open questions for a developer. Drawn from judge rulings of `unresolved` with `route: developer`: candidates where the code question could not be settled statically. Each entry carries the candidate, what was already checked, and ONE precise question. These are NOT findings and must not be counted as findings, listed in the findings table, or described as vulnerabilities -- they are requests for a fact the audit could not establish. Present them as a short list a developer can answer without re-reading the whole finding. If there are none, say so in one line.
10. Optional Patch Set

Do NOT produce an overall security score, security grade, architecture score, architecture grade, or any aggregate letter-grade or numeric rating for the application as a whole. Aggregate scores and grades do not meaningfully reflect application security posture and are explicitly excluded. Per-finding severity and per-finding risk scores ARE retained (see RISK SCORING) -- the exclusion applies only to rolled-up overall scores and grades.

Do NOT produce a remediation plan with time estimates, effort estimates, or scheduling. Time-to-remediate estimates are not reliable and should not be guessed. Findings carry their severity and fix guidance; sequencing and scheduling are left to the team that owns the code.

**OUTPUT FORMATS (MANDATORY):**

You MUST generate the following stakeholder deliverables. Note the output patterns differ by deliverable -- this is intentional based on tested generation behavior.

OUTPUT PATTERN A -- single-call HTML (used for outputs that complete reliably in one tool call):

1. **Final Report (HTML)** -- Complete audit report including all sections listed above
   - Every finding from findings_registry.md is included; no summarization that drops findings
   - Produced in a single create_new_file call
   - HTML: `audit_state/05_consolidated_report.html`

2. **Executive Briefing (HTML)** -- Concise executive summary (2-4 pages) containing:
   - Selected findings per this rule: every Critical finding, plus each High finding that appears in a Top 3-5 attack path. (Since SEVERITY SCOPE means the registry contains ONLY Critical/High findings, "Critical or High" selects everything and would duplicate the Final Report -- this rule is what keeps the briefing at 2-4 pages. Remaining High findings are represented by a one-line count pointing to the Final Report, not by entries.)
   - Top 3-5 attack paths
   - Produced in a single create_new_file call
   - HTML: `audit_state/executive_briefing.html`
   - Do NOT include an overall security grade or score, an architecture grade or score, a prioritized remediation roadmap, or a recommendations section. The briefing presents the most serious findings and the attack paths they enable; it does not roll them into an aggregate grade or a scheduled roadmap.

OUTPUT PATTERN B -- Markdown intermediate followed by HTML rendering (used for the comparison output, which has tested as too content-dense for single-call HTML):

3. **Threat-Audit Comparison Markdown** (COORDINATED mode only) -- the canonical content artifact for the headline deliverable. The HTML deliverable is produced in Phase 6 from this Markdown via scaffold-and-fill; in Phase 5, only the Markdown is produced.

This output ranks above the consolidated report and executive briefing in importance. The reader of the eventual HTML deliverable should be able to read it standalone and understand what the threat model anticipated, what the code actually has wrong, what was missed by the threat model, and what to do about all of it -- WITHOUT having to open `02-threats.md` or `findings_registry.md` to fill in context.

In Phase 5, produce the comparison as Markdown only:

Use `create_new_file` to write `audit_state/threat_audit_comparison.md`. This is the canonical content artifact -- everything described in the Structure section below goes in this file with full per-entry detail. The Markdown form has tested reliably at large sizes (typically 100-200KB), so single-call generation is appropriate. Phase 6 then renders this Markdown to HTML.

CRITICAL CONTENT DISCIPLINE for the Markdown comparison: each entry in Sections 2, 3, 4, and 5 must contain actual content reproduced from the threat model and findings registry, NOT just IDs and pointers. A reader seeing "Threat 07 confirmed by F-001" with no further detail cannot act on that. The reader must see what the threat said, where the code is broken, with what evidence, and how to fix it -- all in one place.

The agent's natural tendency on this output is to summarize aggressively (list IDs, count categories, produce a thin index). That tendency is wrong here. The comparison output is comprehensive by design. Every entry contains essential row-level content.

Structure:

- Section 1: Executive Summary
  - One paragraph synthesizing how well the threat model anticipated the code-level reality: what proportion of threats were confirmed, what kinds of issues were unanticipated, whether there's severity divergence between the model and the audit.
  - Counts table: total threats in the threat model main table, total ledger leads (Code-level + Unverified + Attested-mitigated rows), total audit findings, threats confirmed, threats partial, seeded leads confirmed (includes former-Inferred Unverified rows the audit verified), attestations verified vs contradicted (Attested-mitigated rows checked, split by outcome), exclusion contradictions, threats unconfirmed, audit unanticipated findings. Include percentages.
  - Both the threat model (Priority 1/2 Confirmed/Likely threats; Priority 1 corresponds to Critical, Priority 2 to High) and the audit (Critical/High per SEVERITY SCOPE in GLOBAL RULES) share the same severity floor, so no severity-floor stratification is needed here -- every unanticipated finding is, by construction, a genuine Critical/High gap in the threat model's coverage, not an artifact of comparing across severity floors.

- Section 2: Threats Confirmed by Audit
  - One entry per threat from `02-threats.md` that has at least one finding with `threat_match = confirms`, PLUS one entry per ledger row with at least one `threat_match = confirms-seeded` finding -- labeled "SEEDED BY THREAT MODEL" and quoting the ledger row's Exclusion Reason clause alongside the finding evidence that verifies it. When that ledger row's reason is `Unverified`, additionally quote the row's confirming question (its `Unverified -- confirm whether ...` clause) alongside the finding evidence that answers it, and note that the audit completed verification the threat model left open -- these entries (what older prompt versions surfaced as "promoted from Inferred") demonstrate a key value of running the two tools together.
  - Each entry MUST contain the following content (do NOT use a table for this -- use a section header per threat with substructure):

    ```
    ### Threat <ThreatID>: <Title>

    **From the threat model:**
    - Priority: <from 02-threats.md; Priority 1 | Priority 2>
    - Component: <from 02-threats.md>
    - Threat Agent: <from 02-threats.md>
    - Description: <full Description from 02-threats.md, not abbreviated>
    - Original Mitigation Recommendation: <full Mitigation from 02-threats.md>

    **Confirmed by audit findings:**
    For each confirming finding (often one, sometimes multiple):
    - Finding <FindingID> (severity: <sev>)
      - Location: <file:line from finding's src field>
      - Issue: <full issue description from findings_registry.md, not abbreviated>
      - Evidence: <full evidence from finding's ev field, including any code snippets, command outputs, or tool results>
      - Fix: <full fix guidance from findings_registry.md>

    **Synthesis:** One sentence explaining specifically how the audit evidence validates the threat. Not "this confirms threat 07" but "the unparameterized query at user_controller.py:45 is exactly the SQL injection vector the threat model anticipated against the Contact search API."
    ```

  - These entries are NOT a table. They are detail blocks. Each is roughly 150-300 words depending on the complexity of the threat and its findings.
  - Sort by Priority (Priority 1 first), then by ThreatID.

- Section 3: Threats Not Confirmed by Audit
  - One entry per threat from `02-threats.md` that has NO finding with `threat_match` of `confirms` or `partial`.
  - For each threat, classify the lack of confirmation into exactly one of these categories, and provide the reasoning:

    - **Appears well-mitigated in code**: The audit examined the relevant component and found no exploitable code defect. The existing security controls (per `02-threats.md`'s SecurityControl column AND the audit's review) appear to address the threat.
    - **Audit did not reach this code**: The audit's partition scope or risk prioritization meant the relevant code was not deeply examined. The threat may still be present; the audit cannot say.
    - **Architectural threat not directly observable in code**: The threat is at a design level (e.g., insecure design pattern, missing operational control, supply chain risk) that the audit's code-level inspection cannot evaluate.
    - **Unable to determine**: The audit examined the component but could not conclusively determine whether the threat is mitigated. Reasons might include: runtime behavior, configuration dependencies, environmental factors not visible in code.

  - Each entry contains:

    ```
    ### Threat <ThreatID>: <Title>

    **From the threat model:**
    - Priority: <from 02-threats.md; Priority 1 | Priority 2>
    - Component: <from 02-threats.md>
    - Description: <full Description from 02-threats.md, not abbreviated>

    **Audit assessment:** <one of the four categories>

    **Reasoning:** <one or two sentences explaining WHY this category applies. For "well-mitigated", cite the evidence in code that mitigates it. For "did not reach", state which partition or files would need additional scope. For "architectural", explain what aspect cannot be observed in code. For "unable to determine", state what would need to be examined to determine.>
    ```

  - "Unable to determine" is an acceptable and frequently honest answer. The agent MUST NOT force a confident category when uncertainty is real.
  - Sort by Priority (Priority 1 first), then ThreatID.

- Section 4: Audit Findings Not Anticipated by Threat Model (the value-add gaps)
  - One entry per audit finding with `threat_match = unanticipated` or `threat_match = contradicts-exclusion`. These are the highest-value entries in the entire comparison output -- they reveal what threat modeling missed or wrongly judged mitigated.
  - `contradicts-exclusion` entries are listed FIRST, clearly labeled "CONTRADICTS THREAT MODEL EXCLUSION", and additionally quote the Excluded Threats Ledger row (EX-NNN, exclusion reason, cited mitigation evidence) that the finding disproves. These are the most serious entries in the section: the threat model looked at this exact concern and concluded it was handled.
  - Findings with `threat_match = excluded-by-design` do NOT get full entries here. List them in a compact table at the end of the section (FindingID, severity, EX-NNN, exclusion reason) with a one-line explanation that their absence from the threat model was a deliberate scoping decision, not a miss. Do not count them in the "unanticipated" totals.
  - Order the full entries by severity (Critical first, then High). All entries here are genuine threat-model misses -- there is no lower-severity subgroup to separate out, since the audit does not produce Medium/Low/Info findings (see SEVERITY SCOPE in GLOBAL RULES).
  - Each entry MUST contain the following content:

    ```
    ### Finding <FindingID>: <Title>

    **From the audit:**
    - Severity: <sev>
    - OWASP Category: <cat>
    - Component: <pid>
    - Location: <file:line from src field>
    - Issue: <full issue description, not abbreviated>
    - Evidence: <full evidence including code snippets where present>
    - Impact: <full impact analysis>
    - Fix: <full fix guidance>
    - Verify: <full verification steps>

    **Why this was unanticipated:** Brief explanation of the gap in threat modeling coverage. Common reasons include: the threat model did not include this component in scope, the OWASP category was not heavily emphasized for this application, the defect is at a level of detail below typical threat modeling (e.g., a missing HTTP header), or the threat model identified the abstract risk but not this specific manifestation.
    ```

  - Sort by severity (Critical first).
  - These are the entries that justify the entire toolchain.

- Section 5: Partial Matches
  - One entry per threat with at least one finding where `threat_match = partial`.
  - Each entry contains:

    ```
    ### Threat <ThreatID>: <Title>

    **From the threat model:**
    - Description: <full Description from 02-threats.md>
    - Mitigation Scope: <what the threat model wanted addressed>

    **Partially addressed by audit finding(s):**
    For each partial finding:
    - Finding <FindingID> (severity: <sev>)
      - Location: <file:line>
      - What this finding addresses: <which aspect of the threat>
      - What remains uncovered: <the gap that no finding fills>

    **Remaining work:** Brief summary of what aspects of the original threat are not addressed by any current audit finding, and where additional investigation should focus.
    ```

  - Sort by Priority (Priority 1 first), then ThreatID.

- Section 6: Coverage Analysis
  - Percentage of threat model entries with at least one confirming finding (severity-weighted and unweighted both shown). Report main-table coverage and ledger-lead coverage (Code-level + Unverified rows verified via confirms-seeded; Attested-mitigated rows reported as verified/contradicted/unchecked) separately.
  - Percentage of audit findings that map to anticipated threats vs unanticipated findings. Since both the threat model and the audit are scoped to Critical/High severity, this single figure is already the meaningful coverage number -- no separate all-findings vs. Critical/High-only split is needed.
  - Priority correlation: does the threat model's Priority distribution align with the audit's severity distribution (Priority 1 ~ Critical, Priority 2 ~ High)? Note any divergence (e.g., the threat model rated 5 threats Priority 1 but only 2 of those have any audit findings -- the other 3 may be well-mitigated or out of reach).
  - Component coverage: are there components in `01-inventory.md` that have neither threat model entries nor audit findings? Flag as potential blind spots.

Do NOT include a "Recommended Next Steps", "Prioritized Roadmap", "Recommendations", or any similar section that sequences or schedules remediation work. The comparison presents what was confirmed, what was not, and what was unanticipated, each with severity and evidence. Sequencing and scheduling the work is left to the team that owns the code -- they have the business context to prioritize, and the audit should not fabricate a priority ordering or time estimates.

- Markdown intermediate: `audit_state/threat_audit_comparison.md` (Phase 5 output, COORDINATED mode only)
- HTML deliverable: `audit_state/threat_audit_comparison.html` (produced in Phase 6 from the Markdown intermediate, not in Phase 5)

In STANDALONE mode, the comparison output is NOT produced (neither Markdown intermediate nor HTML deliverable).

**Important: Each output file is its own create_new_file call.** Do NOT attempt to produce multiple files in a single response. Each Phase 5 deliverable -- consolidated report HTML, executive briefing HTML, comparison Markdown -- gets its own create_new_file call with the agent's full response budget allocated to that one file. Producing them as separate calls means each has fresh capacity and content quality stays consistent.

**HTML GENERATION REQUIREMENTS (for Phase 5 HTML outputs):**
- Use semantic HTML5 with clean, professional styling
- Include table of contents with anchor links
- Use collapsible sections for detailed findings where appropriate
- Ensure tables are responsive and readable
- Include inline CSS for standalone viewing
- Set classification markings in header/footer. The marking text is user-supplied: if the user has not specified one by Phase 5, ask once ("What classification marking should the reports carry?") and use the answer; if the user declines or does not answer, use "Internal Use Only". Never invent an organization-specific marking.
- consolidated_report.html and executive_briefing.html: produced in a single create_new_file call each (these have tested reliably as single-call HTML)
- Apply the same minimize-preamble discipline above to each HTML generation step
- ASCII-only output per the ASCII-ONLY OUTPUT global rule (restated here because HTML deliverables are where encoding glitches become stakeholder-visible)

WRITE (Phase 5):
- audit_state/05_consolidated_report.html (HTML deliverable, single-call)
- audit_state/executive_briefing.html (HTML deliverable, single-call)
- audit_state/threat_audit_comparison.md (COORDINATED mode only; Markdown intermediate, Phase 6 will render it to HTML)

ALSO:
- Generate audit_state/C4_architecture.md from persisted c4_input.md state -- this file goes INSIDE audit_state/, not the workspace root; the workspace root belongs to the source repo and must not accumulate audit artifacts (sole exception: security_architecture_audit.md, the cross-run log -- see below)
  - Include Level 1 (System Context) and Level 2 (Container) diagrams
  - Use Mermaid syntax for IDE compatibility
  - Highlight trust boundaries and high-risk data flows
- Update `.\security_architecture_audit.md` (workspace root -- the fixed cross-run location declared in STATE FILE SYSTEM) idempotently from consolidated state only
  - This is a persistent audit log across multiple audit runs. It lives at the workspace root precisely so that archiving `audit_state/` between runs does not orphan it; reading the existing file here is expected and exempt from the fresh-run "never read prior state" rules -- it is by design the only cross-run artifact
  - Finding IDs are date-based (F-NNN), so the ID alone CANNOT serve as the cross-run identity of a finding -- the same defect re-discovered in a later run gets a new ID. Match findings across runs by the stable content key: (pid + src file path + sub + normalized title). When the key matches an existing entry, UPDATE that entry in place (status, evidence, latest finding ID, last-seen date) instead of appending a duplicate. When the key is new, append. When a previously logged finding's key produces no match in the current run, mark its entry "not observed in latest run" rather than deleting it.
  - Track remediation over time via the status field on each entry

Before printing the mode-appropriate banner, update audit_state/STATE.md:
- In COORDINATED mode: mark Phase 5 done; Resume Instruction = "Begin Phase 6 (Comparison HTML Render)."
- In STANDALONE mode: mark Phase 5 done and ensure Phase 6 is not_applicable; Resume Instruction = "Audit complete."

**Phase 5 Completion Banner:**

In COORDINATED mode:
```
=== PHASE 5 COMPLETE: CONSOLIDATION WRITTEN ===
  audit_state/05_consolidated_report.html
  audit_state/executive_briefing.html
  audit_state/threat_audit_comparison.md   <-- input for Phase 6
Comparison HTML deliverable will be produced in Phase 6.
STATE.md updated: Phase 5 marked done.
Type 'proceed' to begin Phase 6 (Comparison HTML Render).
```

In STANDALONE mode:
```
=== PHASE 5 COMPLETE: AUDIT FINISHED ===
  audit_state/05_consolidated_report.html
  audit_state/executive_briefing.html
No threat model detected; no comparison output produced.
Phase 6 is SKIPPED in STANDALONE mode.
STATE.md updated: Phase 5 marked done, Phase 6 not_applicable.
The audit is complete.
```

STOP
===== END FILE: references/phase-5.md

===== BEGIN FILE: references/phase-6.md
<!-- SKILL VERSION: v2-skill (2026-08-14a) -->

# Phase 6 -- Comparison HTML Render (SUBAGENT, COORDINATED mode only)

Renders `audit_state/threat_audit_comparison.md` (the Phase 5 intermediate) into
`audit_state/threat_audit_comparison.html`.

## When this phase does not run

In STANDALONE mode it does not run at all. `STATE.md` should already carry
`Phase 6 (Comparison HTML Render): not_applicable`, set at init, so resume logic never waits on a
phase that was never going to execute. Confirm that and move on -- do not mark it `pending`, and do
not produce an empty or placeholder comparison file.

STANDALONE is a fully supported path, not a degraded one. It must not rot: the test suite exercises
both modes, and a change that only works in COORDINATED is an incomplete change.

## Why this is a separate phase at all

The comparison is produced as a Markdown intermediate in Phase 5 and rendered here, rather than
generated as HTML in one call, because it has tested as too content-dense for single-call HTML
generation. That is OUTPUT PATTERN B in the carved text. Do not "simplify" this into a single step --
the two-step shape is the fix for a known failure, not an accident.

## Render, do not re-analyse

Your input is the Markdown intermediate. Your job is to render it. Do NOT re-derive the comparison
from `findings_registry.md` and the threat model, do not re-run the matching, and do not change any
verdict. If the intermediate looks wrong, say so in your summary and return -- the orchestrator will
re-run Phase 5's comparison subagent. Silently correcting it here would leave the Markdown and the
HTML disagreeing, with no indication which one a reader should trust.

## Content discipline the render must preserve

The carved text is explicit: entries must contain actual content reproduced from the threat model and
the findings registry, not just ids and pointers. A reader seeing "Threat 07 confirmed by F-012" with
no further detail cannot act on it. The reader must see what the threat said, where the code is
broken, with what evidence, and how to fix it -- in one place.

If the Markdown intermediate already satisfies this, carry it through faithfully. Rendering must not
compress it back into pointers to save space.

`contradicts-exclusion` entries lead the section and stay prominent. Those are findings where the
threat model examined this exact concern and concluded it was handled, and the audit found otherwise
-- the most consequential output of coordinated mode.

## Overrides of the carved methodology below

- **Its STOP and "type proceed" banner:** no user to prompt. Write the HTML,
  return the completion banner verbatim in your summary, end your turn (`common.md` rule X-a).
- **STATE.md:** orchestrator-owned. Do not mark Phase 6 done; report it and the orchestrator records
  it.
- Finding ids appear as `F-NNN` -- three digits, no date prefix, ever. If the Markdown intermediate
  carries a date-prefixed form from an older run, render it as written rather than rewriting ids,
  and flag the mismatch in your summary. Never GENERATE a date-prefixed id yourself.

- **The reciprocal copy into the threat-model directory:** the carved text tells you to copy the
  finished HTML to `{PROJECT_NAME}-threat-model/threat_audit_comparison.html`, and its completion
  banner lists that path. `common.md` rule W confines your writes to `audit_state/`, and rule 6 makes
  the threat-model directory read-only to this skill.

  Resolution: **do not write it.** Produce `audit_state/threat_audit_comparison.html` only, and when
  you return the completion banner, say plainly in your summary that the reciprocal copy was not made
  and why. The orchestrator can place it with the user's say-so -- it is his threat model, and a copy
  into another tool's output directory is his call, not a subagent's side effect. Do not report a
  file you did not write.

- **`create_new_file` and `single_find_and_replace`** in the carved text are the names the source
  prompt's harness used. They mean whatever file-write and in-place-edit tools THIS harness
  provides -- the Write and Edit tools, per `common.md` rule W. What matters is the shape the
  carved text describes, not the names: one file per write call, and one targeted replacement per
  placeholder rather than rewriting the whole file.

## Methodology

### PHASE 6 -- COMPARISON HTML RENDER (COORDINATED mode only)

In STANDALONE mode, Phase 6 is SKIPPED entirely. The audit ends at Phase 5.

Phase 6 exists as a separate phase from Phase 5 because Phase 5's accumulated work (consolidated report HTML, executive briefing HTML, comparison Markdown, C4 architecture, security_architecture_audit update) typically consumes 70-80% of a session's response budget by the time the Markdown comparison is complete. The remaining session budget is not enough to reliably produce a complete comparison HTML via scaffold-and-fill (seven tool calls of substantial content each). Phase 6 gets its own fresh session budget for the HTML rendering work.

INPUT (ALL REQUIRED):
- audit_state/coordination_mode.md (MODE must be COORDINATED; if STANDALONE, STOP with error)
- audit_state/threat_audit_comparison.md (must exist and be non-empty)

PRE-FLIGHT CHECKS:

Read `audit_state/coordination_mode.md` first. If MODE is STANDALONE, STOP immediately and report: "Phase 6 invoked but coordination mode is STANDALONE. Phase 6 is only relevant when a threat model exists. The audit is already complete after Phase 5; no further work is needed."

Read `audit_state/threat_audit_comparison.md`. If the file is missing or empty, STOP and report: "Phase 6 invoked but the comparison Markdown intermediate is missing or empty. Phase 5 did not produce the required input. Re-run Phase 5 (which will rebuild the Markdown from findings_registry.md and the threat model)."

CRITICAL EXECUTION DISCIPLINE:

Phase 6 produces the comparison HTML using a scaffold-and-fill pattern. Minimize preamble before producing each tool call. Do NOT write extensive prose describing what the HTML will contain before producing it. Each tool call is small and bounded; the budget concern in Phase 6 is the number of calls accumulated across the phase, not the size of any one call.

Do NOT re-think, re-summarize, or compress content during HTML rendering. The Markdown intermediate is authoritative. Each fill takes its section's existing content and wraps it in HTML markup. If you find yourself shortening entries to "fit" during rendering, STOP -- you are doing the wrong thing. The whole point of the scaffold-and-fill approach is that each fill has enough budget to render its section's content faithfully.

STEP 1 -- Write the HTML skeleton.

Use `create_new_file` to write `audit_state/threat_audit_comparison.html` containing:
- Full DOCTYPE and `<html>` opening
- `<head>` with `<meta charset="UTF-8">`, title, and complete inline `<style>` block covering severity colors (Critical #b00020, High #e65100 -- per SEVERITY SCOPE no other severities exist in audit content), system-ui font stack, print-friendly layout, sticky left-side TOC
- `<body>` opening
- Title heading and a brief introductory paragraph (1-2 sentences identifying this as the headline deliverable of the audit)
- A `<nav class="toc">` element containing a placeholder comment
- A `<main>` element containing one `<section>` per content area, each with its heading and a unique placeholder comment

The seven placeholder comments to include in the skeleton, in order:
1. `<!-- COMPARISON-TOC -->` (inside the `<nav>`)
2. `<!-- COMPARISON-EXECUTIVE-SUMMARY -->`
3. `<!-- COMPARISON-CONFIRMED-THREATS -->`
4. `<!-- COMPARISON-UNCONFIRMED-THREATS -->`
5. `<!-- COMPARISON-UNANTICIPATED-FINDINGS -->`
6. `<!-- COMPARISON-PARTIAL-MATCHES -->`
7. `<!-- COMPARISON-COVERAGE -->`

The skeleton itself is small (5-10KB) and reliably fits in one call. Section 6 (Coverage Analysis) fills the final placeholder.

STEP 2 -- Fill each placeholder.

Seven `single_find_and_replace` calls, one per placeholder. For each fill:
- Read the corresponding section from `audit_state/threat_audit_comparison.md`
- Render that section's content into HTML, preserving the per-entry detail
- Apply the styling rules: severity-colored entry borders, structured layout per entry, no collapsibles for primary content
- Each fill is a separate generation call with fresh capacity, which is how this approach avoids the per-call ceiling

Section fill rules:

1. TOC: a `<ul>` of `<li><a href="#section-id">Section Name</a></li>` entries linking to each main section by id. Brief and structural.

2. Executive Summary: the executive summary content from the Markdown (synthesis paragraph plus counts table).

3. Confirmed Threats: each entry from Section 2 of the Markdown becomes an `<article class="entry severity-{level}">` block containing the threat-model context, the confirming finding(s), and the synthesis. Preserve all the content from the Markdown -- do NOT compress for the HTML rendering.

4. Unconfirmed Threats: each entry from Section 3 becomes an `<article>` block. Include the threat description and the agent's reasoning category with explanation.

5. Unanticipated Findings: each entry from Section 4 becomes an `<article class="entry unanticipated severity-{level}">` block with full finding content. These are the highest-value entries; ensure they get prominent visual treatment.

6. Partial Matches: each entry from Section 5 becomes an `<article>` block.

7. Coverage: render Section 6 from the Markdown as its HTML equivalent (coverage statistics).

If any single_find_and_replace fails (placeholder not found, or the fill content itself truncates), retry only that one fill. The other completed sections remain on disk and are unaffected. If a single fill (most likely the Confirmed Threats or Unanticipated Findings fill, since those are the largest) truncates, the recovery is to manually split that section in half and run two fills against it -- but this should be a rare case and is not the expected workflow.

STEP 3 -- Copy the HTML deliverable to the threat model directory.

After all seven fills complete and the HTML is verified intact, copy the file:
- From: `audit_state/threat_audit_comparison.html`
- To: `{PROJECT_NAME}-threat-model/threat_audit_comparison.html`

This is a one-way copy; do not modify any other files in the threat model directory. The Markdown intermediate stays in `audit_state/` only and is not copied.

WRITE (Phase 6):
- audit_state/threat_audit_comparison.html (HTML deliverable, produced via scaffold-and-fill)
- {PROJECT_NAME}-threat-model/threat_audit_comparison.html (copy for threat model directory)

Before printing the banner, update audit_state/STATE.md: mark Phase 6 done; Resume Instruction = "Audit complete."

**Phase 6 Completion Banner:**
```
=== PHASE 6 COMPLETE: AUDIT FINISHED ===
  audit_state/threat_audit_comparison.html
  {PROJECT_NAME}-threat-model/threat_audit_comparison.html (reciprocal copy)
STATE.md updated: Phase 6 marked done.
The audit is complete.
```

STOP
===== END FILE: references/phase-6.md


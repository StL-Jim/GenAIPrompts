# STRIDE Skill Conversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `stride-threat-model` Claude Code skill (orchestrator + per-phase subagents) by carving the frozen v24 monolith into per-phase reference files, per designs/2026-07-21-stride-skill-conversion-design.md.

**Architecture:** SKILL.md is the orchestrator (only thing that talks to the user; owns STATE.md; dispatches phase subagents). references/ holds methodology text carved verbatim from the monolith with a fixed substitution table for harness scaffolding. scripts/ holds the PowerShell the prompt already mandates. Phase 1 runs as three parallel partition agents plus a reconciliation agent; Phase 3 exports and Phase 4 run as three parallel agents.

**Tech Stack:** Claude Code skills (SKILL.md + references), Claude Code Agent/Task subagents, PowerShell 5.1 scripts, git.

## Global Constraints

- Source freeze: carve ONLY from commit `192f852` (`git show 192f852:stride-threat-model-prompt.md`), v24 stamp `2026-07-16a`. No methodology changes.
- Skill name: `stride-threat-model`. Skill lives at `skills/stride-threat-model/` in the GenAIPrompts repo. Branch: `stride-v25-skill`.
- Version stamp: every generated skill file carries `SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a)` as its first line (HTML-comment or `#` comment as the format allows). Bump the letter on later skill-changing commits.
- ASCII-only in all skill files (the monolith's own Operating Rule 14 discipline applies to the skill text itself).
- Scripts are PowerShell 5.1, no Python (decision recorded 2026-07-21).
- Gate policy default `three-gates`; `all-gates` fallback must exist.
- Subagents never write STATE.md; the orchestrator is the single writer.
- Commit after every task; commit messages end with the Co-Authored-By Claude trailer used on this branch.

## The Substitution Table (applied during every carve task)

Carved text is verbatim EXCEPT these mechanical substitutions. Anything changed that is not on this list is a carve defect. S7/S8 are the only substitutions that require judgment; flag every S7/S8 application in the task's commit message body.

| # | Monolith text | Skill text |
|---|---|---|
| S1 | `read_file` / `ls` / fenced `read_file filepath:` blocks | "Read <path> with the Read tool" (one prose line per file; delete the fenced tool blocks) |
| S2 | `create_new_file` | "the Write tool" |
| S3 | `single_find_and_replace` | "the Edit tool" |
| S4 | "Mark `phase-X: in-progress` in STATE.md before continuing." and end-of-phase STATE.md update instructions | "STATE.md is orchestrator-owned. Do not read-modify-write it; the orchestrator marks phase status." (one line, first occurrence per file; delete the rest) |
| S5 | Banner lines "Type 'proceed' to begin ..." / "wait for the user to type `proceed`" | "Return this banner verbatim as the end of your completion summary." |
| S6 | References to Continue.dev, its tool names, its known bugs, "the workspace root IS the source repo" tooling paragraph (monolith L9) | delete |
| S7 | Fresh-session-per-phase / session-management advice (Rule 1's second half, Rule 9's parenthetical tail, Phase 2 intro's session framing L577-583) | delete (subagents have fresh windows natively); keep the sub-phase ORDER statements |
| S8 | Inline PowerShell blocks that became scripts/ (Phase 0 step 5a manifest, Phase 0 Pass 2 sweep, Phase 4 validation) | "Run `& $SKILL_DIR\scripts\<name>.ps1 -Workspace $WORKSPACE -ProjectName $PROJECT_NAME` and paste its output" (keep every surrounding prose sentence about WHY and what the artifacts mean) |
| S9 | "Verify per Operating Rule 7(d)" | "Verify per common.md rule W-d" (rule renumbering below) |

---

### Task 1: Scaffolding and install.ps1

**Files:**
- Create: `skills/stride-threat-model/install.ps1`
- Create: `skills/stride-threat-model/references/.gitkeep` (deleted in Task 2), `skills/stride-threat-model/scripts/.gitkeep` (deleted in Task 3)

**Interfaces:**
- Produces: the directory layout every later task writes into; `install.ps1` used by the user on both machines.

- [ ] **Step 1: Create directories and install.ps1**

```powershell
# skills/stride-threat-model/install.ps1
# SKILL VERSION: v25-skill (2026-07-21a) -- installer
param([string]$Target = (Join-Path $HOME ".claude\skills\stride-threat-model"))
$src = $PSScriptRoot
if (Test-Path $Target) { Remove-Item -Recurse -Force $Target }
New-Item -ItemType Directory -Force $Target | Out-Null
Copy-Item -Recurse -Force "$src\*" $Target
Get-Content (Join-Path $Target "SKILL.md") -TotalCount 5 | Select-String "SKILL VERSION"
"Installed stride-threat-model to $Target"
```

- [ ] **Step 2: Verify** -- run `powershell -File skills/stride-threat-model/install.ps1 -Target <scratchpad>\install-test`; expect the copy to appear (SKILL.md check will fail until Task 9 -- acceptable now, re-run in Task 11).
- [ ] **Step 3: Commit** `feat(skill): scaffold stride-threat-model skill directory + installer`

### Task 2: references/common.md (executor operating rules)

**Files:**
- Create: `skills/stride-threat-model/references/common.md`

**Interfaces:**
- Produces: the rule file EVERY subagent reads first. Rule numbering: keep the monolith's numbers for carved rules (2,3,4,5,8,9,10,13,13a,14,15,16) so phase-file cross-references ("Operating Rule 2") stay valid; replace 6 and 7 with new rules R (reading) and W (writing); 1, 11, 12 are orchestrator-owned and absent here.

- [ ] **Step 1: Extract the verbatim pieces.** From `git show 192f852:stride-threat-model-prompt.md`:
  - L4-7 (IDENTITY minus L9's tooling paragraph) -- opens the file after the version-stamp comment.
  - L11-13 (Required Inputs).
  - Rules 2 (L19-27), 3 (L29), 4 (L31), 5 (L33), 8 (L73-98), 9 (L100, apply S7 to the parenthetical session note at the end), 10 (L102), 13 (L139), 13a (L141), 14 (L143-155), 15 (L157), 16 (L159-164).
- [ ] **Step 2: Write the two replacement rules and the subagent-conduct rule** (new text, exact content):

```markdown
R. Reading files. Use the native tools: Read for a single file, Glob for filename
   patterns, Grep for content search across the repo. PowerShell Select-String and
   Get-Content remain available for tool-computed accounting artifacts. The cap litmus
   from the original workflow still binds: -First/-Last or any truncation is for
   EXPLORATORY display only -- output that feeds an accounting artifact (sweep,
   candidates, ledger counts, any tool-computed number) must flow tool -> variable ->
   file without display and without caps; a cap is safe only if a later UNCAPPED
   mechanical step covers the same ground. Never use cat, grep, find, head, tail, or
   other POSIX aliases in PowerShell.

W. Writing output files. All output goes under {PROJECT_NAME}-threat-model/. Use the
   Write tool for new files (full content, overwrites), the Edit tool for surgical
   changes to existing output. Create directories with New-Item -ItemType Directory
   -Force. (W-d) After every write, verify: Get-Item <file> | Select-Object Length,
   LastWriteTime and Get-Content <file> -TotalCount 3. Missing, zero bytes, or
   unexpected first lines -> rewrite.

X. Subagent conduct. You are a subagent: you cannot ask the user anything. If you hit
   a decision only the user can make, STOP, write any partial output to disk, and
   return the question in your completion summary -- the orchestrator relays it.
   STATE.md is orchestrator-owned: never write it. Your completion summary is <= 15
   lines: the phase completion banner, files written with byte sizes (tool-computed),
   any question or warning for the user, and -- if incomplete -- exactly what remains.
```

- [ ] **Step 3: Verify** -- `Select-String -Path skills/stride-threat-model/references/common.md -Pattern 'create_new_file|single_find_and_replace|Continue|read_file'` returns nothing; rules 2/9/15/16 present by grep.
- [ ] **Step 4: Commit** `feat(skill): common.md executor rules carved from v24`

### Task 3: scripts/ (manifest, sweep, partition, drawio validation)

**Files:**
- Create: `skills/stride-threat-model/scripts/manifest.ps1`, `sweep.ps1`, `partition-manifest.ps1`, `validate-drawio.ps1`
- Test fixture: `<scratchpad>/fixture-mini/` (six files, see Step 1)

**Interfaces:**
- Produces: all four accept `-Workspace <abs path> -ProjectName <name>`; all write into `<Workspace>\<ProjectName>-threat-model\`; all end by printing tool-computed counts (Rule 15 output the agent pastes).
- `manifest.ps1` -> writes `00-file-manifest.txt`, prints `Manifest file count: N`. Body = monolith L260-280 block verbatim, parameterized.
- `sweep.ps1` -> writes `00-discovery-raw.txt`, `00-density.txt`, `00-candidates.txt`, prints per-pattern counts + `Candidates (tool-computed): N`. Body = monolith L330-363: the nine patterns L331-339 materialized as a `$patterns` array, the L342-363 block made concrete (`<all manifest files>` = paths from 00-file-manifest.txt minus the binary-extension exclusion list on L330).
- `partition-manifest.ps1` (NEW) -> reads `00-file-manifest.txt`, writes `00-manifest-docs.txt`, `00-manifest-iac.txt`, `00-manifest-rest.txt`. First match wins, docs before iac: docs = `(^|/)(README|ARCHITECTURE|DESIGN|SECURITY|THREAT)[^/]*$` OR extension `.md .puml .plantuml .mmd .drawio .dsl .c4 .proto .graphql .wsdl` OR path contains `docs/ doc/ documentation/ adr/ architecture/decisions/` OR filename matches `openapi.* swagger.*`; iac = extension `.tf .tfvars` OR filename `Dockerfile* docker-compose*` OR path contains `k8s/ manifests/ helm/ charts/ .github/workflows/` OR filename `.gitlab-ci.yml Jenkinsfile azure-pipelines.yml buildspec.yml`; rest = everything else. Prints all three counts plus `docs+iac+rest = N  manifest total = N  match: yes/no`.
- `validate-drawio.ps1` -> body = monolith L1326-1337 verbatim, parameterized; prints the per-file lines.

- [ ] **Step 1: Build fixture** at `<scratchpad>/fixture-mini/`: `README.md` (mentions "integrates with the Acme Payments API"), `docs/adr/001.md`, `main.py` (reads `os.environ["DATA_BUCKET"]`, calls `https://api.acme.example`), `terraform/s3.tf` (one bucket resource), `Dockerfile`, `tests/test_main.py`.
- [ ] **Step 2: Write the four scripts** per the Interfaces block above.
- [ ] **Step 3: Test against fixture** -- run manifest, sweep, partition in order with `-Workspace <fixture> -ProjectName fixture-mini`. Expected: manifest count 6; partition docs=2, iac=2, rest=2, match yes; sweep candidates > 0 and `DATA_BUCKET` present in `00-candidates.txt`; `00-discovery-raw.txt` lines carry `path:line:` prefixes. For validate-drawio: write a minimal valid `.drawio` (two cells, one edge) and one with a dangling edge ref into `<fixture>\fixture-mini-threat-model\diagrams\`; expect `parsed OK ... bad edge refs 0` and `bad edge refs 1` respectively.
- [ ] **Step 4: Commit** `feat(skill): extract Phase 0/4 PowerShell into scripts/ + manifest partitioner`

### Task 4: references/phase-0.md

**Files:**
- Create: `skills/stride-threat-model/references/phase-0.md`

**Interfaces:**
- Consumes: scripts from Task 3.
- Produces: the phase file the ORCHESTRATOR itself executes (Phase 0 is interactive; no subagent). Its output contract is unchanged: 00-scope.md, 00-file-manifest.txt, 00-discovery.md + raw/density/candidates/resources, STATE.md initialized (orchestrator-owned, so here the STATE writes STAY -- S4 does not apply to phase-0.md), the Q1-Q6a answers, the Scope Proposal + banner.

- [ ] **Step 1: Extract** L187-404 from the freeze commit into the file (after the version-stamp line).
- [ ] **Step 2: Apply substitutions** -- S2 (step 4 init-STATE and step 8 scope-write become Write tool), S8 (step 5a block -> `scripts/manifest.ps1`; Pass 2 block L342-363 -> `scripts/sweep.ps1` -- keep L326-341 prose and pattern rationale verbatim), S5 (banner L400-401 -> "Present this Scope Proposal to the user and wait for approval or corrections (GATE 1)").
- [ ] **Step 3: Append one new paragraph** (partition hand-off): "After the user approves the Scope Proposal, run `scripts/partition-manifest.ps1` and paste its reconciliation line. The three partition files drive the parallel Phase 1 passes."
- [ ] **Step 4: Verify** -- grep clean per Task 2 Step 3 pattern; every step number 1-10 present; Q1-Q6a text byte-identical to source (compare with `git show 192f852:... | sed -n '291,321p'` against the corresponding file region).
- [ ] **Step 5: Commit** `feat(skill): phase-0.md carved (orchestrator-run, scripts wired)`

### Task 5: Phase 1 files (shared, 1a, 1b, 1c, reconcile)

**Files:**
- Create: `references/phase-1-shared.md`, `phase-1a.md`, `phase-1b.md`, `phase-1c.md`, `phase-1-reconcile.md` (all under `skills/stride-threat-model/`)

**Interfaces:**
- Consumes: `00-manifest-docs.txt` / `-iac.txt` / `-rest.txt` (Task 3), 00-scope.md, 00-discovery.md.
- Produces: 1A/1B/1C agents write `01a-partial.md` / `01b-partial.md` / `01c-partial.md` (schema below -- canonical names, NO final IDs); reconcile agent writes `01-inventory.md` per the verbatim v24 schema and returns the draft System Restatement.

- [ ] **Step 1: phase-1-shared.md** = version stamp + carve of L424-439 (Goal, FILE COVERAGE ACCOUNTING, ENUMERATE BY IDENTITY, COMPREHENSION CROSS-CHECK; S1 on L439) + L443 exclusions paragraph (moved here from 1A because it binds all passes) + this new text:

```markdown
## Partition Contract (parallel passes)
Phase 1 runs as three parallel agents, one per manifest partition (docs / iac / rest,
written by scripts/partition-manifest.ps1). Your accounting universe is YOUR partition
file: every file in it ends as read-and-assigned or skip-bucketed, per the coverage
rules above. You may READ any file in the repo for context (a doc references code, IaC
references an app dir), but you ACCOUNT only for your partition. Do not assign final
IDs -- the reconciliation agent discovers all elements first, sorts alphabetically by
canonical name, then numbers (the fixed-sort rule requires the full set). Refer to
elements by canonical name.

## Partial Inventory Schema (write EXACTLY this structure)
# Phase 1<A|B|C> Partial Inventory -- partition: <docs|iac|rest>
## Elements Found
### <canonical name>
- Element class: component | data-store | external-integration | trust-boundary-evidence
- <then the attribute fields for that class, copied from the 01-inventory.md schema
  sections 2/3/4/5 in phase-1-reconcile.md -- same field names, no ID line>
## Partition File Accounting
- Partition file count: <N> (tool-computed: (Get-Content <partition file>).Count)
- Read and assigned: <N> | Skip-bucketed: tests <N>, generated <N>, vendored-third-party <N>, build-config <N>, docs <N>, assets/static <N>, non-production <N> | Unaccounted: <N>
- Skip-bucket dependency check: <none | list>
- Files read: <list>
## Comprehension Delta Candidates (referenced but NOT in 00-discovery.md)
- <name> -- [evidence: ...]
## Notes for Reconciliation
- <dedupe hints: "the S3 bucket in terraform/s3.tf is the same store main.py calls DATA_BUCKET", cross-partition references, uncertainties>
```

- [ ] **Step 2: phase-1a.md** = stamp + "Read common.md, phase-1-shared.md, STATE.md, 00-scope.md, 00-discovery.md, and your partition file 00-manifest-docs.txt" + carve L441-452 (skip L443, already in shared; drop L454 pass-order paragraph -- S7, obsolete under parallelism) + "Write 01a-partial.md per the shared schema. Unaccounted must be 0; if you run out of room, write what you have and return the remaining file list (the orchestrator re-dispatches a continuation)."
- [ ] **Step 3: phase-1b.md** = same framing with `00-manifest-iac.txt` + carve L456-463 + partial-write paragraph (target `01b-partial.md`).
- [ ] **Step 4: phase-1c.md** = same framing with `00-manifest-rest.txt` + carve L465-476 + partial-write paragraph (target `01c-partial.md`). Keep L476's component-definition warning verbatim -- it is the W7 load-bearing text.
- [ ] **Step 5: phase-1-reconcile.md** = stamp + rehydration list (common.md, phase-1-shared.md, STATE.md, 00-scope.md, 00-discovery.md, 00-file-manifest.txt, all three partials) + this new reconciliation procedure + carve of L478-554 (the full 01-inventory.md schema, verbatim) + L556 completion gate (S4/S5-adapted: incompleteness is RETURNED to the orchestrator with the remaining-files list) + L560 restatement paragraph adapted (below):

```markdown
## Reconciliation Procedure (in order)
1. Merge: union the Elements Found sections of the three partials. Dedupe by canonical
   name and evidence overlap; consult each partial's Notes for Reconciliation. A store
   found in IaC (1B) and referenced in code (1C) is ONE element with both citations.
2. Apply the Section 2 component definition to the merged set: every data store,
   managed service, queue, cache, gateway, and identity provider is ALSO a component.
3. Assign IDs by the fixed-sort rule: sort each class alphabetically by canonical
   name, then number C-001..., DS-001..., EXT-001..., TB-001...
4. Coverage: sum the three Partition File Accounting blocks; the three partition
   counts must sum to the manifest total (paste the partition-manifest.ps1
   reconciliation line, or recompute with (Get-Content ...).Count). Total Unaccounted
   must be 0 -- if any partial reported unfinished files, STOP and return the list.
5. Discovery Delta: union the three Comprehension Delta Candidates lists, dedupe,
   cross-check against 00-discovery.md, and record per the Coverage Report schema.
   Scope-relevant deltas are flagged in your summary for the user.
6. Write 01-inventory.md per the schema below. The System Restatement section is
   written as: "PENDING USER CONFIRMATION: <your draft restatement paragraph>".
7. Return in your summary: the draft System Restatement (verbatim), component/TB/
   assumption counts, the coverage reconciliation line, and scope-relevant deltas.
   The orchestrator relays the restatement to the user (GATE 2) and edits the final
   confirmed text into 01-inventory.md.
```

- [ ] **Step 6: Verify** -- schema region of phase-1-reconcile.md byte-matches L478-554 except substitutions (word-diff); grep clean; each of the five files under 200 lines except reconcile.
- [ ] **Step 7: Commit** `feat(skill): Phase 1 carved as parallel partition passes + reconciliation agent`

### Task 6: references/phase-2a.md, phase-2b.md, phase-2c.md

**Files:**
- Create: the three files under `skills/stride-threat-model/references/`

**Interfaces:**
- Consumes/produces: unchanged from v24 (02a-context.md, 02b-threats.md + explainer HTML, 02c-assumptions.md + consolidated 02-threats.md).

- [ ] **Step 1: phase-2a.md** = stamp + carve L585-675. Substitutions: S1 (rehydration block), S4, S2, S5 (banner).
- [ ] **Step 2: phase-2b.md** = stamp + carve L679-868. Substitutions: S1, S4, S2, S5. NOTHING else changes -- this file is the methodology heart (prioritization, confidence, speculation audit, IAM gate, 21-column schema, explainer); the carve must be byte-faithful.
- [ ] **Step 3: phase-2c.md** = stamp + carve L872-991. Substitutions: S1, S4, S2, S3 (the ledger-append advice L933), S5. KEEP the PowerShell consolidation block L969-978 inline and verbatim (it is an artifact contract, not harness scaffolding).
- [ ] **Step 4: Verify** -- word-diff each file against its source range; only substitution-table lines differ. Confirm the 21-column schema table and the example row are byte-identical.
- [ ] **Step 5: Commit** `feat(skill): Phase 2A/2B/2C carved verbatim`

### Task 7: Phase 3 files (dispositions, html, csv)

**Files:**
- Create: `references/phase-3-dispositions.md`, `phase-3-html.md`, `phase-3-csv.md`

**Interfaces:**
- Orchestrator runs Disposition Discovery Steps 1-3 (L1023-1077) itself -- they are scripts + a possible user question (Case C). It then dispatches: the dispositions agent ONLY when a dispositions.csv was found; then html + csv (+ phase-4) in parallel.
- `phase-3-dispositions.md` agent -> writes `03-dispositions-matched.md`: a table `| ThreatID | OriginalPriority | RevisedPriority | Disposition | DispositionRationale |` (one row per HIGH-confidence match only) + the match report line L1096.
- `phase-3-html.md` / `phase-3-csv.md` agents -> read 02-threats.md and (if present) 03-dispositions-matched.md; write outputs/threat-model.html and outputs/threats.csv.

- [ ] **Step 1: phase-3-dispositions.md** = stamp + rehydration (common.md, STATE.md, 02-threats.md, the dispositions.csv path the orchestrator passes in the briefing) + carve L1079-1103 (Matching Procedure + Priority revision handling) + the new output-artifact paragraph: "Write every high-confidence match to 03-dispositions-matched.md per the table above; low/medium-confidence candidates are listed below the table under '## Not Transferred' with one-line reasons. Return the match report line."
- [ ] **Step 2: phase-3-html.md** = stamp + carve L998-1015 (Phase 3 rehydration, S1/S4 applied) + this line: "If 03-dispositions-matched.md exists, read it; its rows are the matched dispositions the format sections below refer to. If absent, all disposition fields render empty/default." + carve L1105-1187 (Goal + 3A in full). S2 on the create_new_file mentions; keep the one-shot/no-preamble/no-abbreviation mandates verbatim.
- [ ] **Step 3: phase-3-csv.md** = stamp + same rehydration head as Step 2 + carve L1189-1218 (3B + CSV rules). S2 applied.
- [ ] **Step 4: Verify** -- word-diff vs ranges; the CSV header line L1195 byte-identical; the export-JS value-mapping rules (L1181) present in phase-3-html.md.
- [ ] **Step 5: Commit** `feat(skill): Phase 3 carved as dispositions/html/csv agent files`

### Task 8: references/phase-4.md

**Files:**
- Create: `references/phase-4.md`

- [ ] **Step 1: Carve** L1233-1353: rehydration (S1, S4), File Creation rules (S2 on create_new_file -- the ONE-SHOT-per-diagram rule stays, restated as "complete XML in one Write call per file"), Visual Standards + style dictionary + layout formula + labels VERBATIM (15f determinism work -- zero drift allowed), Per-Diagram Specifications verbatim, Validation section with S8 (`scripts/validate-drawio.ps1`), banner with S5.
- [ ] **Step 2: Verify** -- style-dictionary strings byte-identical (grep for `fillColor=#438DD5;strokeColor=#2E6295` count matches source); the Unicode-exception glyphs survive intact.
- [ ] **Step 3: Commit** `feat(skill): phase-4.md carved (validation via script)`

### Task 9: SKILL.md (the orchestrator)

**Files:**
- Create: `skills/stride-threat-model/SKILL.md`

**Interfaces:**
- Consumes: everything above. Produces: the user-facing skill.

- [ ] **Step 1: Write SKILL.md with exactly this content** (adjust nothing without noting it in the commit):

````markdown
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
- Phase 3 Disposition Discovery (YOU, before group B): execute the discovery steps in
  the carved text at the end of this file's companion -- run
  Get-ChildItem -Directory -Filter "$PROJECT_NAME-threat-model-*", check each for
  dispositions.csv, then branch: Case A (none) print the acknowledgment and skip the
  dispositions agent; Case B (found) dispatch phase-3-dispositions with the newest
  file's path; Case C (dirs but no csv) ASK THE USER for a path or explicit skip --
  never skip silently. Then GATE 3 has already passed, so dispatch group B.
- Phase 4 return: paste the validation output from the agent's banner verbatim. If any
  file reports PARSE FAIL or nonzero bad refs, re-dispatch phase-4 for the failing
  file(s) -- a failing diagram is not done.
- Run end: print the archiving reminder from references/phase-0.md's companion block
  verbatim (carved at the end of phase-4.md), then summarize deliverable paths.

## Failure handling
- Agent returns but an expected output file is missing/empty: re-dispatch that phase
  once with the discrepancy named; if it fails again, stop and tell the user.
- Agent returns a question (rule X): relay it, get the answer, re-dispatch with the
  answer appended to the briefing.
- You die mid-run: STATE.md is the spine; the next session resumes per Session Start.
- Numbers in banners are computed, never recalled (common.md rule 15) -- reject and
  re-request a summary whose counts have no pasted command output.
````

- [ ] **Step 2: Fix the archiving-reminder location** -- Step 1's text says the reminder is carved "at the end of phase-4.md": append monolith L1357-1370 to phase-4.md (verbatim, S5 not needed) as `## Archiving Reminder (returned to the orchestrator)`, and verify SKILL.md's "Run end" bullet points there.
- [ ] **Step 3: Verify** -- the dispatch table's phase files all exist in references/ (`Test-Path` loop); frontmatter parses (name, description present); no reference to a gate or file this plan did not create.
- [ ] **Step 4: Commit** `feat(skill): SKILL.md orchestrator -- gates, dispatch table, failure handling`

### Task 10: concat build artifact + carve verification pass

**Files:**
- Create: `skills/stride-threat-model/scripts/concat-monolith.ps1`
- Create: `designs/2026-07-21-carve-verification.md` (the review record)

- [ ] **Step 1: concat-monolith.ps1** -- concatenates, in monolith order (common, phase-0, phase-1-shared, 1a, 1b, 1c, 1-reconcile, 2a, 2b, 2c, 3-dispositions, 3-html, 3-csv, 4), with a header line `BUILD ARTIFACT -- generated by concat-monolith.ps1 from v25-skill; the skill files are canonical`, into `<scratchpad or -OutFile>\stride-threat-model-concat.md`. Runs and produces non-empty output.
- [ ] **Step 2: Mechanical scan** -- across all references/ files: `Select-String -Pattern "create_new_file|single_find_and_replace|Continue\.dev|type 'proceed'|edit_existing_file"` -> zero hits; `Select-String -Pattern "SKILL VERSION"` -> one hit per file.
- [ ] **Step 3: Word-diff review** -- for each carved file, word-diff against its freeze-commit line range (`git show 192f852:stride-threat-model-prompt.md | sed -n 'A,Bp'` into temp files, `git diff --no-index --word-diff`). Every diff hunk must map to a substitution-table row or a documented structural addition (partition contract, reconcile procedure, dispositions artifact). Record per-file verdicts in `designs/2026-07-21-carve-verification.md`.
- [ ] **Step 4: Nuance-loss watchlist pass** -- walk the memory watchlist's check questions against the carved files; record answers in the same verification doc. Any confirmed loss is fixed before commit.
- [ ] **Step 5: Commit** `chore(skill): concat build artifact + carve verification record`

### Task 11: End-to-end smoke test

**Files:**
- Create: `<scratchpad>/fixture-app/` -- a richer fixture: flask `app/main.py` + `app/auth.py` (env-var DB access, one plaintext HTTP client call), `terraform/` (S3 bucket + RDS + IAM role), `Dockerfile`, `.github/workflows/deploy.yml`, `README.md` naming one external SaaS, `docs/architecture.md`, `tests/`.
- No repo files modified except fixes discovered.

- [ ] **Step 1: Install** the skill (`install.ps1`, real target) and open a Claude Code session with `<scratchpad>/fixture-app/` as the workspace.
- [ ] **Step 2: Full run, three-gates** -- invoke the skill; answer Q1-Q6a; approve gates. Verify at each stage: version line printed first; Phase 0 artifacts + partition reconciliation line; group A runs as three concurrent agents; partials have no C-NNN IDs; 01-inventory.md IDs are alphabetically sorted; restatement gate offers confirm/correct and the correction lands in the file; 2A->2C auto-proceed; 02-threats.md size >= sum of parts; group B runs concurrently; HTML has the AI banner + sidebar TOC + dispositions controls; CSV header matches the contract line; all four .drawio pass validate-drawio.ps1.
- [ ] **Step 3: Resume test** -- delete nothing; kill the session after 2A completes; new session; verify it announces resume at 2B and completes without redoing 0-2A.
- [ ] **Step 4: Incompleteness test** -- temporarily add 30 dummy source files to the fixture, re-run only group A with an artificially small instruction ("stop after 10 files and report remaining") to verify the orchestrator re-dispatches a continuation; then remove dummies.
- [ ] **Step 5: Fix everything found** (edit skill files; each fix is a substitution-table or orchestrator bug, never silent methodology change), re-run affected stage, then commit `fix(skill): smoke-test fixes -- <list>` and bump the stamp letter to `2026-07-21b`.

### Task 12: Documentation, push, work handoff

- [ ] **Step 1: README** -- add a `## stride-threat-model skill` section to the repo README: what it is, install command for the work machine (`git pull; powershell -File skills/stride-threat-model/install.ps1`), the canonical-source rule (monolith frozen at v24; skill canonical after A/B), gate policy summary.
- [ ] **Step 2: Push** the branch. Do NOT merge to develop (A/B comparison decides canonical first; merge sequencing is the user's call per the recorded rule).
- [ ] **Step 3: Report** to the user: what was built, smoke-test results with evidence, the one-line work-machine install instruction, and the A/B protocol reminder.

## Self-Review Record

- Spec coverage: Sections 1-9 of the design map to Tasks 1-12; deferred items (2B fan-out, drawio generator, CSV script, double-run union) appear in no task -- correct. STATE.md EXECUTOR_HARNESS + GATE_POLICY: Task 9. Nuance-loss review + concat diff: Task 10. Build-machine field test incl. kill/resume: Task 11.
- Placeholders: none -- carved content is specified by freeze-commit line range + substitution table (the content exists at `192f852`; copying 155K chars into this plan would be the error).
- Type consistency: partial filenames (01a/01b/01c-partial.md), partition filenames (00-manifest-docs/iac/rest.txt), 03-dispositions-matched.md, and script parameter contracts are named identically in Tasks 3, 5, 7, 9.

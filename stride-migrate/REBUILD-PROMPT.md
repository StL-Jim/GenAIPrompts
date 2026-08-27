# REBUILD: STRIDE Threat Model Skill

You are rebuilding a Claude Code skill from a source prompt. This file is the complete
specification. Follow it in order. Do not improvise structure, and do not "improve" the
methodology text you are moving -- your job is a faithful carve plus a small, explicitly
listed set of additions.

Everything in this file is ASCII. Keep it that way in everything you write.


## 0. What you are building and why

The STRIDE threat model exists in two forms. The older form is a single monolithic prompt
(about 1500 lines) that one agent executes top to bottom. The newer form is a Claude Code
skill: an orchestrator plus per-phase reference files, where each phase runs in a dedicated
subagent with its own context window.

The skill form cannot be installed here from outside. So you are rebuilding it, locally,
from the monolith -- which IS available here -- plus this file.

The monolith carries the METHODOLOGY. This file carries the ORCHESTRATION, which does not
exist in the monolith and cannot be derived from it.

Why the skill form matters, so you do not talk yourself out of the split: the monolith is
about 192 KB, roughly 48-62 K tokens depending on tokenizer. Loaded whole, before reading a
single line of the repo under assessment, it consumes a third of a 200 K window. The phase
split exists so each phase gets a clean window. Do not collapse phases back together.


## 1. Preflight -- verify your inputs, then STOP if anything is missing

All three inputs travel with this file. This document lives at `stride-migrate/REBUILD-PROMPT.md`
in the GenAIPrompts repository, on the `stride-migrate` branch, and the paths below are
relative to the REPOSITORY ROOT -- the parent of the directory this file is in. Nothing needs
to be copied anywhere first.

Confirm all four before writing anything. Report what you found.

1. **The monolith:** `archive/stride-threat-model-prompt.md`. Confirm it contains a line
   starting `# IDENTITY and PURPOSE` and one starting
   `## Phase 4 -- C4 Model and Data Flow Diagrams`. Report its version stamp (expected: v25,
   dated 2026-08-10).
2. **The renderer:** `skills/stride-threat-model/scripts/render-drawio.ps1`. Confirm its first
   lines mention `Phase 4 diagram renderer`. Report its version stamp (expected: v26-skill,
   2026-08-10a).
3. **The validator:** `skills/stride-threat-model/scripts/validate-drawio.ps1`.
4. **The skills directory.** Confirm `~/.claude/skills/` exists, or the equivalent on this
   machine, and report the absolute path you will install to.

If the monolith is missing, STOP -- there is nothing to carve and this rebuild cannot
proceed.

**If either .ps1 is missing, do NOT stop, and do NOT write them yourself** (section 7.1 says
why). They are not inputs to the carve; nothing is derived from their text. They are needed
for exactly one thing: verifying the Phase 4 data-file schema by round-trip. So continue the
rebuild, and handle Phase 4 like this:

- Write `phase-4.md` against the schema exactly as given in section 7.1.
- Mark it plainly, in the file itself, as `SCHEMA UNVERIFIED -- round-trip not run`.
- Skip the two-node round-trip.
- In your completion report, state that the renderer was absent, name the deferred check, and
  give the user this instruction verbatim:

      Copy render-drawio.ps1 and validate-drawio.ps1 into
      <SKILL_DIR>\scripts\, then ask Claude Code to run the section 7.1
      round-trip: write a two-node one-edge 04-diagram-data.json, run the
      renderer, run the validator, and confirm a .drawio file appears and
      parses. Then remove the SCHEMA UNVERIFIED marker from phase-4.md.

The specific field most likely to be wrong is the EDGE LABEL. The node fields were confirmed
against the renderer's parsing code; the edge label was inferred from the node handling and
never confirmed. If it is wrong, flows render as unlabelled arrows -- a diagram that looks
plausible and is missing information, which is the failure mode worth naming out loud because
nothing else in the run will flag it.

### YOU WILL SEE EIGHT MORE SCRIPTS. DO NOT COPY THEM.

`skills/stride-threat-model/scripts/` also contains `check-threats.ps1`, `readset.ps1`,
`sweep.ps1`, `consolidate.ps1`, `init-workspace.ps1`, `manifest.ps1`, `partition-manifest.ps1`
and `archive-compare.ps1`. They belong to the CURRENT skill, which is a later version than the
one you are rebuilding, and they are not yours to take.

Six of them you will write yourself from the specifications in Appendix C. Two of them
(`partition-manifest.ps1`, `archive-compare.ps1`) this rebuild does not use at all.

Copying them instead of writing them is the obvious shortcut and it is wrong here: they are
built against the current skill's file layout and phase structure, not the v25 structure this
rebuild produces, so a copied script will reference files that will not exist. If you believe
copying is nonetheless correct, STOP and say so rather than doing it silently -- that is a
decision for the person running this, not for you.


## 2. Rules that bind this rebuild

- **Carve, do not rewrite.** When this file says a section moves from the monolith to a
  reference file, move the text VERBATIM. You are not editing the methodology. Where a
  passage names something that no longer exists (a Continue.dev tool, an operating rule that
  was dropped), fix only that reference and leave the surrounding text alone.
- **Duplicate rather than dangle.** If a passage binds two phases, copy it into both files.
  A duplicated paragraph is cheap. A reference to a passage that lives in a file the agent
  did not read is a silent failure.
- **Anchor on headings, never on line numbers.** Every split below is expressed as a heading
  range. Your copy of the monolith may not have the line numbers this file was written
  against.
- **ASCII only, and no markdown emphasis in .md output.** This is Operating Rule 14 and it
  binds the files you are writing, not just the files the skill later produces.
- **Count the writes.** This rebuild produces 16 files. Each is one write. Do not split a
  file across multiple writes, and do not write a file twice to "fix it up" -- get it right
  in one pass.


## 3. Target file tree

    stride-threat-model/
      SKILL.md                          <- section 6, Appendix A
      references/
        common.md                       <- section 4
        phase-0.md                      <- section 5
        phase-0-discovery.md            <- section 5
        phase-1.md                      <- section 5
        phase-2a.md                     <- section 5
        phase-2b.md                     <- section 5
        phase-2c.md                     <- section 5
        phase-3.md                      <- section 5
        phase-4.md                      <- section 5, and see 7.1
      scripts/
        render-drawio.ps1               <- COPY the one you have. Do not regenerate.
        validate-drawio.ps1             <- COPY the one you have. Do not regenerate.
        init-workspace.ps1              <- section 7, spec C-1
        manifest.ps1                    <- section 7, spec C-2
        readset.ps1                     <- section 7, spec C-3
        sweep.ps1                       <- section 7, spec C-4
        check-threats.ps1               <- section 7, spec C-5
        consolidate.ps1                 <- section 7, spec C-6

Three scripts that exist in the newer skill are deliberately NOT rebuilt:
`partition-manifest.ps1` (nothing is partitioned here -- see section 5, Phase 1),
`archive-compare.ps1` (compares against a previous archived run; there is none on a first
run, and the step that calls it is dropped), and `concat-monolith.ps1` (a build artifact of
the source repo, not part of a run).


## 4. Build references/common.md

This file is read first by every subagent. It is the monolith's Operating Rules, minus the
rules that the orchestrated form replaces, plus five rules that exist only in the skill form.

Write it in exactly this order:

    ## Required Inputs
    <-- monolith "## Required Inputs", verbatim -->

    ## Operating Rules (every subagent reads these before any work)

    2.  <-- monolith Rule 2 "Evidence or it didn't happen", VERBATIM -->
    3.  <-- monolith Rule 3 "No hallucinated CVEs", VERBATIM -->
    4.  <-- monolith Rule 4 "Enumerate, don't generate", VERBATIM -->
    5.  <-- monolith Rule 5 "Deterministic IDs", VERBATIM -->
    R.  <-- Appendix B, rule R -->
    W.  <-- Appendix B, rule W -->
    S.  <-- Appendix B, rule S -->
    V.  <-- Appendix B, rule V -->
    X.  <-- Appendix B, rule X -->
    8.  <-- monolith Rule 8 "Output directory layout", VERBATIM -->
    9.  <-- monolith Rule 9 "Reading large files COMPLETELY", VERBATIM EXCEPT: drop the
            trailing parenthetical session-management note that begins "(Session-management
            note". It tells the agent to prefer a fresh session per phase, which is what the
            orchestrator now does for it. -->
    10. <-- monolith Rule 10 "Get the current date and time", VERBATIM -->
    13. <-- monolith Rule 13 "Production scope only", VERBATIM -->
    14. <-- monolith Rule 14 "ASCII-only output", VERBATIM -->
    15. <-- monolith Rule 15 "Numbers are computed, never recalled", VERBATIM -->
    16. <-- monolith Rule 16 "AI-generation disclosure", VERBATIM -->

The numbering gaps are intentional and must be preserved. Rules are cited by number
throughout the phase files, so renumbering them would break every citation.

**Five monolith rules are DROPPED. Do not carry them:**

| Dropped | Why |
|---|---|
| Rule 1, Phase discipline | It tells the agent to stop and wait for the user to type `proceed`. A subagent cannot talk to the user. The orchestrator's gates replace this entirely. Carrying it would deadlock every phase. |
| Rule 6, Reading files -- Continue.dev built-ins | Names a different harness's tools. Replaced by rule R. |
| Rule 7, Writing output files | Same reason. Replaced by rule W. |
| Rule 11, When uncertain, stop and ask | Directly contradicts rule X. A subagent that stops and asks hangs the run. Rule X gives it the correct behaviour: return the question in the completion summary. |
| Rule 12, STATE.md is the resume signal | STATE.md is now written by the orchestrator alone. Its schema and rules live in SKILL.md. A subagent that reads and rewrites STATE.md corrupts it. |



## 5. Build the phase reference files

Each file below starts with this one line, then the carved content:

    <!-- Read references/common.md before this file. -->

DO NOT put a version stamp in these files, or in common.md. SKILL.md carries the only stamp
in the skill, and it is the one the orchestrator prints and records in STATE.md. A stamp
repeated across fifteen files is fifteen things to update on every change and fifteen chances
to leave one stale -- and a stale stamp is worse than none, because it makes a file look
current when it is not.

### phase-0.md

Source: monolith `## Phase 0 -- Initialization and Scoping`, steps 1 through 10.

Phase 0 runs in the ORCHESTRATOR's own session, not a subagent, because it asks the user
questions. So this file is read by the orchestrator itself.

Carve it with these changes:

- **Steps 1, 2, 3, 5** are replaced by a single call to `init-workspace.ps1` (spec C-1).
  Replace those four steps with one step that runs the script and prints its output. The
  script does what those steps described; keep any prose that explains WHY, drop the inline
  PowerShell blocks.
- **Step 4** (initialize STATE.md) stays, but point it at the STATE.md schema in SKILL.md
  rather than restating one.
- **Step 6** (pre-flight questions Q1-Q6a) stays VERBATIM. This is user dialogue and it is
  the orchestrator's job.
- **Step 7** splits. Its exposure-validation part (7.6) stays here -- it feeds the Scope
  Proposal the user adjudicates. Its DISCOVERY body -- the enumeration and reading work --
  moves to `phase-0-discovery.md`. In its place write: dispatch the discovery subagent per
  the SKILL.md dispatch table, then run `readset.ps1 -Verify` yourself and act on the
  verdict.
- **Step 7.7**, the archived-run comparison, is DROPPED. It needs `archive-compare.ps1` and
  a prior archived run; neither exists.
- **Steps 8, 9, 10** stay VERBATIM.

### phase-0-discovery.md

Source: the discovery body of monolith Phase 0 step 7 -- the enumerate-by-concrete-identity
instruction, the detection-file list, and the sweep.

Add to it: a step that runs `sweep.ps1` (spec C-4), and a step that writes
`00-files-read.txt` listing every file the agent actually opened. That file is not optional
decoration -- `readset.ps1 -Verify` reads it, and without it the orchestrator cannot check
discovery coverage at all.

This is the reading-heavy heart of the whole workflow. Whatever else you compress, do not
compress this file's instructions to read deeply.

### phase-1.md

Source: monolith `## Phase 1 -- Documentation, Diagram, and Source Analysis` in full,
INCLUDING its `### Phase 1A -- Documentation Pass`, `### Phase 1B -- Infrastructure-as-Code
Pass`, and `### Phase 1C -- Application Source Pass` subsections. Then append the entire
`# Architectural Inventory` section that follows it in the monolith -- sections 1 through 7,
Documentation Artifacts through Coverage Report. That is Phase 1's output schema and it
belongs in this file.

**One agent runs 1A, 1B and 1C sequentially, exactly as the monolith describes.** The newer
skill splits these across three parallel agents over a partitioned file manifest and then
merges them with a reconcile agent. Do not attempt that here. The partition machinery and the
merge agent are skill-only inventions that are not in the monolith, and a merge done wrong
produces an inventory that looks complete and is not. Sequential is slower and correct.

Keep the pass-order rule verbatim -- the one that says to run 1C before 1B when
infrastructure files are thin. It is load-bearing for platform-inherited deployments.

### phase-2a.md, phase-2b.md, phase-2c.md

Sources:

| File | Monolith section |
|---|---|
| phase-2a.md | `# Phase 2A -- Assets, Trust Boundaries, Data Flows` |
| phase-2b.md | `# Phase 2B -- STRIDE Threat Tables` |
| phase-2c.md | `# Phase 2C -- Exclusions and Coverage` |

The monolith has a `## Phase 2 -- STRIDE Threat Enumeration` preamble sitting above all
three. **Read it and distribute it by what it binds**, applying the duplicate-rather-than-
dangle rule:

- Anything about assets, asset tiering, trust boundaries or data flows -> phase-2a.md.
- Anything about threat inclusion criteria, the exploitability / already-compromised test,
  the architecture-level (design-level) test, the L3/L4 prerequisite likelihood cap, the
  Impact rule, or the threat table schema -> phase-2b.md.
- Anything about exclusions, the ledger, or coverage accounting -> phase-2c.md.
- Anything that binds two of them -> copy into both.

The 21-column threat table schema in Phase 2B must be carried exactly, in order. It is
validated mechanically by `check-threats.ps1` and the column order is part of that contract.
The order is:

    ThreatID, Confidence, Priority, Category, OWASP, Component, TrustBoundary, Title,
    ThreatAgent, Asset, Attack, AttackSurface, Impact, Description, Evidence, Likelihood,
    SecurityControl, ResidualRisk, Mitigation, Disposition, DispositionRationale

Add to phase-2b.md, at the end of the walk instructions, this progress line -- it is the one
addition to 2B in this rebuild and it exists because a field run went 80 minutes with no
signal of any kind:

    SAY WHERE YOU ARE AS YOU GO. After each component's six-category pass, emit exactly one
    line and nothing else:

        [2B] Component <n> of <N> (<C-NNN>) -- <p> promoted, <x> excluded

Also add to phase-2b.md, immediately before its audit steps:

    WRITE 02b-threats.md AND 02b-excluded.md THE MOMENT THE WALK ENDS -- before the audits
    below, not at the end of the phase. ONE Write call per file, not one per component.
    Then run the audits as Edits against the files on disk. An audit that finds nothing
    writes nothing.

The reason, which you may keep or drop from the file: the audits run at maximum context
pressure against data that, until they are written, exists nowhere but in the agent's head.

### phase-3.md

Source: monolith `## Phase 3 -- Multi-format Export`, in full, including its
`### 3A -- HTML`, `### 3B -- CSV for Excel` and `### 3C -- Stakeholder Explainer`
subsections and the `### Phase 3 Disposition Discovery` section.

This single file is dispatched THREE times in parallel, each agent told to produce only one
of 3A / 3B / 3C. Write the file so that instruction makes sense: each subsection must be
self-contained enough that an agent can execute it without executing the other two. Add a
line near the top:

    Your briefing names ONE of the three outputs below. Produce only that one. The other
    two are being produced in parallel by other agents; do not write their files.

Disposition Discovery is the ORCHESTRATOR's job, not this agent's -- it is already specified
in SKILL.md. Keep the section here for reference but mark it clearly as orchestrator-owned.

### phase-4.md

Source: monolith `## Phase 4 -- C4 Model and Data Flow Diagrams (draw.io)`, plus the
`## Archiving for Future Runs` section that follows it.

**This is the one phase file that must be substantially rewritten rather than carved, and
the rewrite is the whole point of carrying the renderer over.** See section 7.1.


## 6. Build SKILL.md

Write it exactly as given in Appendix A. Do not paraphrase it and do not reorder it. The
GATE 3 section in particular has been through many revisions and its wording is deliberate.

Substitute only `<today's date>` in the version stamp.


## 7. The scripts

### 7.1 Phase 4 and the renderer -- read this before writing phase-4.md

The monolith emits draw.io XML directly from prose: it gives the agent geometry rules and
has it compute coordinates by hand. `render-drawio.ps1` exists BECAUSE that did not work.
Its own header says so:

    the layout rules are ~50 coordinates, a dozen four-decimal attachment fractions and a
    channel assignment per edge, for every diagram. An agent computing that by hand on a
    25-component system will get some of it wrong, and one wrong coordinate is a visibly
    broken diagram.

and:

    Every rule below was confirmed by rendering a sample and looking at the exported PNG.
    Six defects found that way were invisible in the spec text.

So: **delete the monolith's prose geometry from phase-4.md.** Do not carry the coordinate
rules, the attachment fractions, the channel assignments, or the raw `<mxCell>` / `<mxGeometry>`
templates. Replace all of it with:

1. The agent writes `{OUTPUT_ROOT}\04-diagram-data.json` -- CLASSIFICATION only, no geometry.
2. The agent runs `render-drawio.ps1`.
3. The agent runs `validate-drawio.ps1` and pastes its output into the completion banner.

Keep from the monolith everything that is NOT geometry: which four diagrams are produced,
what belongs in each, how components map to tiers, which flows are drawn, and the AI-generation
notice required by Rule 16.

The data file schema, confirmed against the renderer's parsing code:

    {
      "diagrams": [
        {
          "name":  "<becomes <name>.drawio in the diagrams/ directory>",
          "title": "<the diagram page title>",
          "notes": ["<optional free-text note lines, rendered in a NOTES box>"],
          "nodes": [
            { "id": "<unique within this diagram>",
              "label": "<display name>",
              "kind":  "component | store | external | actor | process | dfdstore",
              "tier":  "ACTORS | EDGE | APPLICATION | DATA | SECURED | EXTERNAL" }
          ],
          "edges": [
            { "source": "<node id>", "target": "<node id>", "label": "<flow label>" }
          ]
        }
      ]
    }

`kind` and `tier` are closed vocabularies -- a value outside them will not render. The
renderer computes every coordinate itself; do not put `x`, `y`, `w` or `h` in the data file.

**Verify this schema against the script rather than trusting it** -- IF the renderer is
present. Read its `ConvertFrom-Json` section and its node and edge handling, and correct the
schema above where it differs. Then prove it end to end: write a small two-node one-edge data
file, run the renderer, run the validator, and confirm a `.drawio` file appears and parses. Do
that BEFORE you write phase-4.md, so the file you write describes something you have actually
seen work.

Pay particular attention to the EDGE fields. The node fields above were confirmed against the
parsing code; the edge label was inferred from the node handling and never confirmed. It is
the single most likely thing here to be wrong.

If the renderer is NOT present, do not stop and do not invent a substitute -- follow the
absent-renderer path in section 1.

### 7.2 The six scripts you are recreating

Specs are in Appendix C. These six differ from the renderer in a way that matters: their
correctness is checkable against a stated contract. `check-threats.ps1` either flags a row
that violates a rule or it does not, and you can test that with a fixture. The renderer's
correctness lived in fifty empirically-tuned coordinates that only a human looking at a
rendered PNG could confirm -- which is why that one is carried and these six are rebuilt.

Every script takes the same two mandatory parameters unless its spec says otherwise:

    param(
      [Parameter(Mandatory=$true)][string]$Workspace,
      [Parameter(Mandatory=$true)][string]$ProjectName
    )
    $ErrorActionPreference = 'Stop'
    $WORKSPACE    = $Workspace.TrimEnd('\')
    $PROJECT_NAME = $ProjectName
    $root = "$WORKSPACE\$PROJECT_NAME-threat-model"

Exit 0 on success, exit 1 on a failure the caller must act on.


## 8. Install

Place the tree at the skills path you confirmed in preflight. Then verify the skill is
visible to Claude Code -- list available skills and confirm `stride-threat-model` appears
with its description. If it does not appear, the frontmatter at the top of SKILL.md is the
first thing to check: `name:` and `description:` must both be present, and the file must
begin with the `---` fence on line 1.


## 9. Verify the rebuild

Do all of these and report each result. Do not report success on any check you did not run.

1. **Every file exists and is non-empty.** List the tree with sizes.
2. **No dangling rule citations.** Grep the reference files for `Rule 1`, `Rule 6`,
   `Rule 7`, `Rule 11`, `Rule 12`, `Continue.dev`, `create_new_file`, `read_file`. Every hit
   is a reference to something this rebuild dropped. Fix each one.
3. **No dangling file references.** Grep for `phase-1a`, `phase-1b`, `phase-1c`,
   `phase-1-shared`, `phase-1-reconcile`, `phase-3-html`, `phase-3-csv`, `phase-3-explainer`,
   `phase-3-dispositions`, `partition-manifest`, `archive-compare`. None of those files exist
   in this rebuild. Every hit is a broken pointer.
4. **Exactly one version stamp.** Grep the whole tree for `SKILL VERSION`. The only file
   that may define one is SKILL.md. References inside SKILL.md to "the stamp above" are
   fine; a stamp line in any references/ file is not.
5. **The threat table schema is intact.** Confirm phase-2b.md lists all 21 columns in the
   order given in section 5, and that `check-threats.ps1` expects the same 21 in the same
   order.
6. **The renderer round-trips.** The two-node test from 7.1, if you have not already done it.
   If the renderer was absent, report that instead -- naming the deferred check, not passing
   over it. An unrun check is never a passed one.
7. **Each script runs.** Invoke each of the six with a throwaway workspace and confirm it
   either does its job or fails with a clear message -- not with a syntax error.
8. **Shell form.** If your shell is bash rather than PowerShell, confirm you can invoke one
   of the scripts through the `powershell.exe -NoProfile -ExecutionPolicy Bypass -File`
   form in common.md rule S. This is where rebuilds usually break first.

Then report: files written, checks passed, checks failed, and anything you changed from this
specification along with why.


## Appendix A -- SKILL.md, write this file exactly

    ---
    name: stride-threat-model
    description: Runs or resumes an orchestrated, multi-agent STRIDE threat model against the current workspace -- phased analysis producing a component inventory, STRIDE threat table, HTML/CSV deliverables, and draw.io diagrams under {project}-threat-model/. Use when asked to run, continue, or resume a threat model or STRIDE analysis, when the user mentions the threat-model STATE.md, or when asked to advance to a specific phase. Not for the Code Security Audit (separate workflow).
    ---
    <!-- SKILL VERSION: v25-rebuild (<today's date>) -->

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
    Schema. Subagents never touch it. A full rewrite MUST preserve the User Inputs section
    verbatim.

        # Threat Model Run State
        PROJECT_NAME: <name>
        WORKSPACE: <path>
        LAST_UPDATED: <ISO 8601>
        EXECUTOR_HARNESS: claude-code-skill <the SKILL VERSION stamp at the top of this file>
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
      Phase 1 (System Restatement confirm/correct -- mandatory user input, never skippable),
      GATE 3 after Phase 2B -- the THREAT REVIEW. All other boundaries auto-proceed, except
      the short asset-tier confirm after 2A described under Phase 2 below, which runs under
      every policy.
      GATE 3 sits after 2B and not after 2C because 2B is the last point at which a
      correction is cheap. Its two files, 02b-threats.md and 02b-excluded.md, are plain
      editable text, and NOTHING has yet been derived from them: not the 2C consolidation,
      not the Excluded Threats Ledger, not the stakeholder explainer, not one export. A
      threat fixed here flows into all of those. The same fix made after consolidation
      leaves every derived file carrying the old text, and the user has no way to see which
      ones drifted.
    - all-gates: additionally pause after 2A, 2C, 3 and 4, presenting each returned banner
      and waiting for the user.
    At every gate: present the returned banner(s) plus anything the agent flagged, then
    wait for explicit user approval. Corrections at a gate are applied before moving on
    (re-dispatch the phase, or make the edit yourself if it is small and mechanical).

    ## Dispatch
    Run Phase 0 YOURSELF, in THIS session, WITH ONE EXCEPTION: its discovery step (step 7)
    is dispatched as a subagent. Phase 0 is interactive -- it asks the user Q1-Q6a and
    presents the scope at GATE 1, and a subagent cannot talk to the user -- so initialization,
    the questions, exposure validation, the scope note and the Scope Proposal all stay here.
    But step 7's DISCOVERY is the reading-heavy heart of the workflow and needs a full,
    dedicated context window: run in this session it competes with orchestration and user
    dialogue, and a model managing a conversation economizes on reading (field-observed:
    fewer files read, integrations missed). So dispatch it, per the table below, briefed on
    references/phase-0-discovery.md.

    When the discovery agent returns, do NOT take its word for its own coverage. RUN THE
    VERIFICATION YOURSELF -- you are a different agent than the one that did the reading, so
    this is an independent check rather than a self-report, and it costs one command:

        & '<SKILL_DIR>\scripts\readset.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>' -Verify

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
    - VERDICT: COMPLETE -> proceed to the Scope Proposal.
    - VERDICT: INCOMPLETE -> re-dispatch the discovery agent with the named unread files listed
      in its briefing. Do not build scope on it. Do not accept an explanation for the gap.
    - Several rescued candidates that Pass 1 missed -> re-dispatch with the shortfall named.
      Nothing downstream detects what discovery missed, so a shallow discovery silently caps the
      entire run. This is the shallowness signal to watch, and it is the only one that is actually
      COMPUTED: the sweep mechanically found resources that Pass 1's reading did not, which is a
      fact about the run rather than an impression of it.
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
          2. <SKILL_DIR>\references\<phase file from the table>
          3. <OUTPUT_ROOT>\STATE.md, then the rehydration files your phase file lists.
        Then execute the phase exactly as specified. <extra line from the table, if any>
        Follow common.md rule X for conduct and your completion summary. You write every
        file your phase specifies; STATE.md is the only file you must not write.

    | Order | Phase file | Parallel group | Extra briefing line |
    |---|---|---|---|
    | 0 | phase-0-discovery.md | -- (during Phase 0 step 7) | Rehydration: STATE.md and 00-file-manifest.txt (00-scope.md does not exist yet). Read deeply; a fast finish on a large repo is a failure, not efficiency. |
    | 1 | phase-1.md | -- | Run passes 1A, 1B and 1C in order, all three, in this one agent. |
    | 2 | phase-2a.md | -- | -- |
    | 3 | phase-2b.md | -- | -- |
    | 4 | phase-2c.md | -- | -- |
    | 5 | phase-3.md | B (with the other two 3s, and 4) | Produce ONLY section 3A (HTML). Do not write the CSV or the explainer. |
    | 5 | phase-3.md | B | Produce ONLY section 3B (CSV). Do not write the HTML or the explainer. |
    | 5 | phase-3.md | B | Produce ONLY section 3C (stakeholder explainer). Do not write the HTML or the CSV. |
    | 5 | phase-4.md | B | -- |

    Launch a parallel group's agents in ONE message (multiple Agent calls). Wait for every
    member before the next step. Groups write disjoint files; only you write STATE.md.

    ## Per-phase orchestrator duties
    - Phase 1: dispatch one agent on phase-1.md. On its return, relay the draft System
      Restatement to the user (GATE 2); after confirm/correct, Edit the final text into
      01-inventory.md's System Restatement section (replacing the PENDING marker) and
      record corrections the user made.
    - Phase 2: dispatch 2a, then 2b, sequentially -- verifying each output file (rule W-d)
      before the next. BETWEEN THEM, after 2a verifies and before 2b is dispatched, PRESENT
      2a's 'Primary assets' LINES TO THE USER and ask them to confirm or correct the tiering.
      This is a short, targeted check -- the asset list, not the whole of 02a-context.md --
      and it exists because everything downstream ranks threats by what they target: Phase
      2B's Impact test reads the tier, so a wrong tier is not visible as a wrong tier later,
      it is visible as threats rated oddly. If the user corrects it, Edit 02a-context.md
      before dispatching 2b.
      After 2b verifies, RUN THE MECHANICAL CHECK YOURSELF (same reasoning as the Phase 0
      read-set verify; rule S for your shell's form):

          & '<SKILL_DIR>\scripts\check-threats.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'

      Exit 1 means rule violations -- fix 02b-threats.md and re-run BEFORE the gate, so the user
      spends the walk on judgement rather than bookkeeping. An unparseable row and a zero-row table
      are both FAILURES, not passes. 2B may run it on itself; your run is the one that counts.

      Then hold GATE 3 -- the threat review. Present 2b's banner, the threat count by
      priority, and anything the agent flagged, then wait for explicit approval. Apply
      corrections to 02b-threats.md and 02b-excluded.md BEFORE dispatching anything else:
      re-dispatch 2b, or make the edit yourself when it is small and mechanical. Only after
      approval dispatch 2c. After 2c verify 02-threats.md exists and is at least the size of
      its three inputs combined.
      Skepticism at this gate points at the SUBAGENT'S OUTPUT, never at the user. The user
      correcting or deleting a threat is the gate working; do not argue the threat back onto
      the list or ask them to justify a removal.

      GATE 3 THREAT REVIEW -- when the user asks for it. This is a DISCUSSION, not a form to fill in. The user questions a threat the way a reviewer does: "is this real?", "isn't that already handled by our WAF?", "the dev team will say this is unreachable". He types what he means, in his own words, and you work out what he is asking.

      TRIGGER. The user asks for this in plain language -- "I would like to review each threat individually", "let me see them one at a time", "walk me through the threats". Any such request starts the review. Default to EVERY threat in the main table, in ThreatID order, one threat per message. He may instead name particular threats, and you may mention that is possible, but do not steer him toward it and never offer an abbreviated path as the easier option: when he asks to review each threat individually, he means each one, and the review is the point of the gate rather than an overhead to minimise.

      SHOW THE THREAT COMPLETE. Head each one with its position in the walk (`Threat 3 of 11`) so the user always knows where he is and how much is left. Every column of the row, nothing omitted and nothing abbreviated, rendered as a LABELLED LIST with one field per line -- a twenty-one column markdown row is unreadable, which is the only reason not to paste the row itself. In schema order: ThreatID, Confidence, Priority, Category, OWASP, Component, TrustBoundary, Title, ThreatAgent, Asset, Attack, AttackSurface, Impact, Description, Evidence, Likelihood, SecurityControl, ResidualRisk, Mitigation, Disposition, DispositionRationale.

      Reproduce Description IN FULL, including its [Prereq:], [Gains:] and [Risk calc:] notes verbatim, and Evidence IN FULL, including EVERY citation rather than the first one. Disposition and DispositionRationale are empty until stakeholder review; show them as empty rather than dropping them. Do not summarise, do not truncate a long field, and do not omit a field because it looks uninteresting or repetitive -- the user is reviewing the threat exactly as it will appear in the report, and a field you hide is a field he cannot correct. If a row is missing a field the schema requires, show it as MISSING rather than passing over it: the gate is the place that defect gets caught.

      Then close with this line, or very close to it:

      `You can accept this (say "next"), ask me to check the evidence (I'll read the actual files), tell me to change something, go back to the previous threat, jump to a number, or stop. Or ask me anything about it.`

      Then stop for his response.

      ADVANCING. Anything that reads as acceptance -- "no", "no, next threat", "next", "fine", "looks good", "nothing" -- means he has nothing to change on that threat: go straight to the next one and print it. Do NOT ask a confirming question, do NOT summarise what he just accepted, and do not remark on the decision; the next thing he should see is the next threat. Note in particular that a bare "no" ANSWERS THE QUESTION YOU ASKED -- it means nothing to ask or change -- and is not a refusal to continue.

      Honour the other things a reviewer says mid-walk: "back" or "previous" re-shows the preceding threat, a numbered request jumps to that threat, and "stop" / "that's enough" / "just proceed" ends the walk and continues with every remaining threat unchanged. When the last threat is done, say so, state the final threat count, list the changes made during the walk, and ask whether to proceed to Phase 2C. Then close with this line exactly, counted from the walk you just ran rather than estimated (rule 15):

      `Review walk: walked <N> of <N> | challenged <N> | held <N> | changed <N> | dropped <N>`

      `challenged` = threats the user questioned instead of accepting; `held` = of those, the ones you kept as written; `changed` = reworded, re-rated or split; `dropped` = rows that left the main table. Print it even when every count is zero. This line exists because of the caution above -- agreeing with most challenges is a signal about YOURSELF -- and that signal is only usable if it is counted and shown rather than noticed privately. Do not editorialise about the numbers or defend them; print the line and stop.

      ANSWERING MEANS GOING AND LOOKING. When the user challenges a threat, RE-READ the files its Evidence column cites before you respond, and report what you found there. Do not defend the row from memory and do not restate its Description in different words -- restating the row is precisely the failure this gate exists to catch, because the row is the thing under question.

      ANSWER HONESTLY, INCLUDING WHEN THE HONEST ANSWER WEAKENS OR KILLS THE THREAT. If re-reading the evidence does not support the row, say so plainly and propose the correct disposition yourself. The goal is a table the user believes, not a table that survives review. A threat you talk the user out of dropping, when they were right, costs far more than that threat was ever worth -- it is exactly how a threat model loses the room.

      ONCE HE DECIDES, APPLY IT. Explaining a threat when asked is answering a question; arguing after the decision is not. Apply it without relitigating and without quietly restoring it in a later phase.

      HOLD THE LINE WHEN THE RULES SUPPORT THE ROW. Changing your assessment because a RULE says so is correct. Changing it because the user pushed is not. He will ask, in these words or close to them, "based on the Phase 2 rules, does this threat belong in the main table?" -- answer it by naming the specific test and showing how the row measures against it: the design-level test, the already-compromised exploitability test, the L3/L4 prerequisite cap, the Impact-to-Gains binding, the evidence requirement of Operating Rule 2. Then give the verdict, whichever way it falls. "It passes the design-level test, because fixing this requires a DECISION rather than correcting one function, and here is the evidence" is a legitimate answer and you must be willing to give it to someone who is plainly hoping for the opposite.

      A threat you drop under questioning that the rules actually supported is the same failure as a threat you invented -- quieter, in the opposite direction, and worse, because the user can SEE a bad threat sitting on the list and cannot see a good one you removed for his comfort. If you notice you are agreeing with most challenges, treat that as a signal about YOURSELF rather than about the threats. Re-reading a rule and finding a genuine violation should be uncommon by this point, because the same rules were applied when the row was written; if it is happening to most rows, the likelier explanation is that you are yielding to the question rather than testing the row. The user is relying on you to be right, not agreeable -- a reviewer who can talk you out of anything learns nothing from you.

      A VERDICT MUST CITE WHAT YOU JUST LOOKED AT, not the rule alone. Naming a test is not applying it. Say which file and lines, which manifest, which configuration or which base image tag you read DURING THIS EXCHANGE and what it showed, and then give the verdict. Two answers are always wrong however true they sound:
      - A restatement of policy. "Consistent with our approach, we exclude things that aren't confirmed architectural vulnerabilities" is not an answer -- it is the rule repeated back, and it is circular, because whether THIS row is confirmed is the entire question being asked.
      - Any justification that would read identically for a different threat. If your sentence would apply word-for-word to any row in the table, it is about the rules rather than about this threat, and you have not answered.
      If you cannot point to something you checked, say so: "I would need to read X to answer that" is a real answer and a policy recital is not. And note that agreeing with the user by way of a rule-shaped sentence is still agreeing with the user -- a rule is not a polite way to concede.

      When a row turns on whether a container can escape, the premise is a fact about files, not about rules: read the base image tag (some variants already default to a non-root UID, which makes the threat FALSE rather than merely code-level), and if it does run as root, check the repo's own manifests for an escape primitive -- privileged, hostPath, a mounted container socket, added capabilities, host namespaces. Root inside a container with no escape reaching anything is dominated by the code execution its prerequisite already required; root plus an escape primitive reaches the node and is a genuine boundary crossing.

      THE OUTCOME OF A DISCUSSION IS RARELY KEEP-OR-DROP. Apply whichever of these fits and say which one you applied:
      - Keep as written.
      - Reword, or narrow the scope -- edit the row.
      - Re-rate: change Priority, Likelihood or Impact. A re-rating must stay consistent with the row's own [Gains:] note and its asset criticality tier per the Impact rule in this phase. If what the user asks for contradicts them, say so once -- plainly, not as an argument -- then do what they asked.
      - Split into two threats, when the discussion shows the row conflated two.
      - "A control we already have covers that" -- usually NOT a drop. If the control is verified in code or IaC, it becomes a `Fully mitigated` ledger row citing that evidence. If the only evidence is the user's word, it becomes `Attested-mitigated (unverified)`, naming the control AND the specific code or IaC check that would confirm it, which the partner code audit then picks up as a verification lead. Operating Rule 2's attestation asymmetry is not suspended because the conversation is happening live.
      - The discussion shows the prerequisite already granted the impact: ledger row, `Not exploitable -- dominated by prerequisite`, stating what the prerequisite already gave the attacker.
      - The discussion shows it is really an implementation defect, not an architectural gap: ledger row, `Code-level`, naming the suspected defect and its location so the code audit can use it as a seeded lead.
      - The user rejects it outright: ledger row, `Rejected at review -- <their reason, or 'no reason given'>`.

      BOOKKEEPING, for every outcome that removes a row from the main table (bookkeeping is not optional): remove the row from 02b-threats.md, append a line to 02b-excluded.md in its four-field form with the reason above, and recompute the Threat Filtering Notes counts in 02b-threats.md so they still describe the file (Rule 15: counted, not recalled). Phase 2C reconciles ledger rows against the not-promoted counts and STOPS on a mismatch, so a threat that merely vanishes from the table fails the run two phases later, in a place that gives no hint the cause was a decision at this gate.

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
        without disposition data." -- and proceed without disposition data.
      - Case B (at least one matched directory has a dispositions.csv): pick the most
        recently modified one and report -- "Phase 3 Disposition Discovery: found
        dispositions.csv at <relative path> (last modified <timestamp>, <N> disposition
        entries). Applying matched dispositions to exports." -- then pass that file's path
        to the 3A and 3B agents in their briefing.
      - Case C (matched directories exist but none has a dispositions.csv): ASK THE USER
        for a path or an explicit skip -- never skip silently. If the user supplies a
        path, VALIDATE it (expected header row, at least one data row) before passing it
        on; if invalid, re-prompt with the specific error. Only an explicit user
        instruction to proceed without disposition data skips validation.
      Dispositions apply to 3A (HTML) and 3B (CSV). They do NOT apply to 3C -- the
      explainer explains threats, not dispositions.
      GATE 3 has already passed at this point; after discovery, dispatch group B.
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


## Appendix B -- the five skill-only rules, write these into common.md verbatim

    R. Reading files. Use the native tools: Read for a single file, Glob for filename
       patterns, Grep for content search across the repo. Read takes an offset and a limit
       for large files -- see rule 9 for how to read a large file completely rather than
       partially. Prefer these to shelling out: they are faster, they do not depend on your
       shell's quoting, and their output is already structured. Use the shell for file
       operations the native tools do not cover (listing with sizes, counting lines,
       running the skill's scripts).

    W. Writing output files. All output goes under {PROJECT_NAME}-threat-model/. Use the
       Write tool for a new file and Edit for a change to an existing one. Four rules bind
       every write:
       (a) One Write per file. Do not write a file incrementally across many calls --
           every write costs the user an approval, and a file assembled from twenty
           appends is twenty interruptions.
       (b) Never write STATE.md. It is the orchestrator's alone. If your phase needs
           something recorded there, say so in your completion summary.
       (c) Write the file BEFORE you audit it, not after. Data that exists only in your
           context is data that is lost if you die, and self-audit runs at the point of
           maximum context pressure. Write first, then correct on disk with Edit.
       (d) VERIFY WHAT YOU WROTE. After writing, confirm the file exists and is non-empty,
           and state its size in your completion summary as a number you computed, not one
           you remember. A phase that reports success on a file it did not verify has not
           completed.

    S. Running the skill's scripts (READ THIS BEFORE YOUR FIRST SCRIPT CALL). All mechanical
       scripts live in {SKILL_DIR}\scripts\ and are PowerShell. The phase files show them in
       PowerShell call form:

           & '<SKILL_DIR>\scripts\<name>.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'

       IF YOUR SHELL TOOL IS BASH (Git Bash on Windows is the common case), that form will
       not run. Translate every call to:

           powershell.exe -NoProfile -ExecutionPolicy Bypass -File '<SKILL_DIR>\scripts\<name>.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'

       Same parameters, single-quoted paths, forward or back slashes both work inside the
       quotes. NEVER paste a multi-line PowerShell block into bash -- the quoting will
       corrupt backslash paths silently and you will not notice until an output file lands
       somewhere wrong. If you need multi-line PowerShell, write it to a temp .ps1 file and
       run that with -File.

    V. Never delegate verification to the user. If a run's correctness can be checked by
       running a command, YOU run it and YOU report what it printed. Do not tell the user
       to run a script, do not suggest they "may want to confirm", and do not describe a
       check you did not perform. Verification that depends on a human remembering a
       command line does not happen.

    X. Subagent conduct. You are a subagent: you cannot ask the user anything. If you hit
       a decision only the user can make, STOP, write any partial output to disk, and
       return the question in your completion summary -- the orchestrator relays it.
       STATE.md is orchestrator-owned. Do not read-modify-write it. Your completion summary
       is <= 15 lines: what you produced, the files you wrote with their verified sizes,
       counts computed by command (rule 15), and any question or flag. Do not include a
       coverage verdict about your own work -- the orchestrator computes those.


## Appendix C -- script specifications

### C-1. init-workspace.ps1

Replaces monolith Phase 0 steps 1, 2, 3 and 5 with one call. It exists because those steps
were multi-line inline PowerShell blocks, and an agent whose shell is bash mangles backslash
paths in them silently.

Does, in order, printing what it does:
1. Derive and print the literal values: WORKSPACE, PROJECT_NAME, OUTPUT_ROOT, and the
   current timestamp from `Get-Date -Format "yyyy-MM-ddTHH:mm"`.
2. Validate the workspace exists and is a directory. Exit 1 with a clear message if not.
3. Create the output tree: `{OUTPUT_ROOT}` and `{OUTPUT_ROOT}\outputs` and
   `{OUTPUT_ROOT}\diagrams`. Idempotent -- do not fail if they exist.
4. Add a git exclude. Append the pattern `{PROJECT_NAME}-threat-model*` -- WILDCARD, not an
   exact name -- to `{WORKSPACE}\.git\info\exclude` if it is not already present. The
   wildcard matters: the archiving step renames the directory with a date suffix, and an
   exact-name entry would stop covering it the moment it was archived. Skip silently, with a
   printed note, if `.git` does not exist.
5. List any existing `{PROJECT_NAME}-threat-model-*` archived directories, with last-modified
   timestamps, so the orchestrator can see prior runs.
6. Print a top-level repo map: the workspace's directories and files to depth 2, with sizes.

### C-2. manifest.ps1

Writes `{OUTPUT_ROOT}\00-file-manifest.txt`: one workspace-relative path per line, forward
slashes, for every file in scope.

Excludes, by directory name at any depth: `.git`, `node_modules`, `vendor`, `target`,
`.venv`, `venv`, `__pycache__`, `dist`, `build`, `.idea`, `.vscode`, and any directory
matching `{PROJECT_NAME}-threat-model*` (the tool's own output, including archived runs).

Excludes, by extension: binaries and media -- `.exe .dll .so .dylib .class .jar .png .jpg
.jpeg .gif .ico .svg .pdf .zip .tar .gz .7z .mp4 .mov .woff .woff2 .ttf .eot`. Also excludes
any file over 2 MB, and prints how many it skipped for size.

Prints the total count. That count is the denominator every coverage check uses, so it must
be computed here and never estimated later.

### C-3. readset.ps1

Two modes. This is the script that makes discovery coverage checkable rather than
self-reported, and it exists because a field run read six source files and reported success.

**Default mode** -- computes the MANDATORY READ SET from `00-file-manifest.txt` and writes it
to `{OUTPUT_ROOT}\00-readset.txt`. A manifest file is in the read set if any of:
- its filename matches a documentation or architecture pattern: `README*`, `ARCHITECTURE*`,
  `DESIGN*`, `SECURITY*`, `THREAT*`, or it sits under `docs/`, `doc/`, `documentation/`,
  `adr/`, `architecture/`;
- it is a diagram or contract source: `*.puml .plantuml .mmd .drawio .dsl .c4 .proto
  .graphql .wsdl`, or `openapi.*` / `swagger.*` / `*.openapi.*`;
- it is a build or dependency descriptor: `package.json`, `pom.xml`, `*.csproj`, `go.mod`,
  `requirements.txt`, `Cargo.toml`, `Gemfile`, `build.gradle*`, `*.sln`;
- it is infrastructure: `*.tf`, `*.tfvars`, `Dockerfile*`, `docker-compose*.y*ml`, `*.y*ml`
  under a `k8s`, `kubernetes`, `deploy`, or `.github/workflows` path; and Helm matched by its
  own MARKER FILES -- `Chart.yaml`, a `helm/` directory, or a `templates/` directory beneath a
  chart -- and NOT by a bare `charts/` prefix.

  That last exclusion is not fussiness. A bare `charts/` prefix was tried in the partner code
  audit and swept 252 chart DATA files (an astrology application) into the config class, which
  bulk filtering then had to throw 226 of them back out. A DIRECTORY NAME IS NOT A ROLE; the
  marker files are. Apply the same principle to any other directory name you are tempted to
  match on;
- it is a configuration or secrets-bearing file: `*.env*` (but NOT `*.env.test` /
  `*.env.dev` -- Rule 13 puts non-production out of threat scope), `*.ini`, `*.conf`,
  `*.properties`, `appsettings*.json`.

Print the count and the path. Exit 0.

**-Verify mode** -- reads `00-readset.txt` and `00-files-read.txt` (which the discovery agent
writes), normalizes both to workspace-relative forward-slash form, lower-cases for
comparison, and diffs.

Print, in this order:
- the read-set size, the read-count, and the coverage as a percentage;
- `UNREAD:` followed by every read-set file not in files-read, one per line, complete -- do
  not truncate this list, it is the actionable output;
- exactly one final line, `VERDICT: COMPLETE` if the unread list is empty, otherwise
  `VERDICT: INCOMPLETE (<n> unread)`.

Exit 0 on COMPLETE, exit 1 on INCOMPLETE.

If `00-files-read.txt` does not exist, print `VERDICT: INCOMPLETE (no files-read record)`
and exit 1. Do not treat a missing record as a pass.

### C-4. sweep.ps1

Phase 0's mechanical pattern sweep over the manifest. Streams matches -- do NOT accumulate
every match object in memory, or a large repo exhausts it.

Patterns, exactly these, as regex, case-insensitive:

    '://'
    's3|bucket|dynamodb|sqs|sns|kinesis|rds|redis|kafka|rabbitmq|mongo|postgres|mysql|elastic|queue|topic'
    'secret|password|token|api[_-]?key|access[_-]?key|credential'
    '\.client\(|\.connect\(|new \w+Client|createClient|connectionString'
    '_URL|_URI|_HOST|_ENDPOINT|_ADDR|_SERVER|_BROKER|_DSN|_QUEUE|_TOPIC|_BUCKET|_TABLE'
    'arn:aws'
    '\b(\d{1,3}\.){3}\d{1,3}\b'
    '([a-z0-9-]+\.)+(com|net|org|io|cloud|internal|corp|local|gov|mil|edu|us)'
    'getenv|environ\[|process\.env'
    '<script[^>]+src=|<iframe[^>]+src=|<embed[^>]+src=|<object[^>]+data='
    'integrity=["'']?sha|crossorigin='
    'fetch\(["'']https?://|axios\.(get|post|put|delete)\(["'']https?://|\$\.(ajax|getJSON)\('

The last three are client-side integration signals and are not optional. The patterns above
them are server-centric; these catch third-party services loaded by the BROWSER -- SDKs, tag
managers, payment and auth widgets, CDN assets, embedded iframes. A browser-to-third-party
call is a real external integration and appears in no server import graph. Field-observed
miss.

Behaviour:
- Skip files already excluded by the manifest, plus any file over 1 MB, and lockfiles
  (`package-lock.json`, `yarn.lock`, `Cargo.lock`, `go.sum`, `poetry.lock`).
- CAP candidate extraction per pattern at 200 distinct candidates. When a pattern exceeds
  the cap, still record the TRUE total count -- accounting is never capped, only extraction --
  and print `SATURATED` on that pattern's line.
- Print one line per pattern: the pattern, its true match count, distinct candidates kept,
  elapsed seconds, and `SATURATED` where it applies. This is the progress signal the
  orchestrator watches.
- Write the extracted candidates to `{OUTPUT_ROOT}\00-resources.txt`, one per line, with the
  pattern that found it and one example file path.

### C-5. check-threats.ps1

Validates `{OUTPUT_ROOT}\02b-threats.md` against the Phase 2B rules that are mechanically
decidable. It exists because the agent that wrote the rows also audited them, in the same
context window, at the point of maximum fill.

Parse the main markdown table. Expect **21 columns** in this order:

    ThreatID, Confidence, Priority, Category, OWASP, Component, TrustBoundary, Title,
    ThreatAgent, Asset, Attack, AttackSurface, Impact, Description, Evidence, Likelihood,
    SecurityControl, ResidualRisk, Mitigation, Disposition, DispositionRationale

A row with a different column count is a PARSE FAILURE -- report it with its line number and
fail. A table with zero data rows is a FAILURE, not a pass.

Then check every row and collect violations:

**Closed vocabularies**
- `Confidence` in {Confirmed, Likely}
- `Priority` in {Priority 1, Priority 2}
- `Category` is one of the six STRIDE categories
- `AttackSurface` is one of the ten permitted values defined in phase-2b.md
- `Likelihood` in {Medium, High} -- Low is excluded by the inclusion gate, so a Low row in
  the main table is a violation
- `ResidualRisk` in {Severe, Elevated}
- `Disposition` MUST be empty during generation (reviewers fill it in later)
- `DispositionRationale` MUST be empty during generation

**Mandatory structure**
- `ThreatAgent` must carry a privilege level in parentheses, matching `\(L[0-4]\)`. Mandatory:
  it is what makes "this needs cluster admin" impossible to hide.
- `Asset` must match the form `AS-NNN (tier)`.
- `Description` must contain the literal notes `[Prereq:`, `[Gains:` and `[Risk calc:`.
  Use a substring test, NOT a `-like` wildcard -- in a `-like` pattern `[` opens a character
  class and the match throws.
- If `ThreatAgent` is L3 or L4, `Description` must also contain a `[Cap escape: path` or
  `[Cap escape: gain` note. Without it the L3/L4 likelihood cap was never lifted, so the row
  belongs in the ledger as `Low likelihood`.

**Risk-calc arithmetic**
- `[Risk calc: ...]` must be in the form `<Likelihood> likelihood x <Impact> impact`.
- The likelihood named there must equal the `Likelihood` column.
- CRITICAL = High x Critical -> Priority 1. HIGH = High x High, OR Medium x Critical ->
  Priority 2. Any other product does not clear the inclusion gate and does not belong in the
  main table.
- The computed outcome must match the `Priority` column.
- Impact may only be Critical when the target asset's tier is Primary or Sensitive. A threat
  against a Supporting asset caps at High however broad the gain.

**Cross-file consistency**
- Every `AS-NNN` in the Asset column must appear in `02a-context.md`.
- Its tier here must equal its tier there. The tier is carried across, never re-judged.

Report: one line per violation, `<ThreatID>: <what is wrong>`. Then a summary count. Exit 1
if there is at least one violation or parse failure, exit 0 otherwise.

### C-6. consolidate.ps1

Phase 2C's final step. Concatenates a header file plus the three Phase 2 sub-files into the
canonical `{OUTPUT_ROOT}\02-threats.md`, then removes the temporary header file.

Do it by streaming through the OS, not by reading the files into the agent's context and
re-writing them -- that is the entire reason this is a script.

Then VERIFY: the result must be at least the combined byte size of its inputs. If it is
smaller, the concat truncated -- print the expected and actual sizes and exit 1. A silent
truncation here loses threats after every gate has passed.


## Appendix D -- what this rebuild does NOT include

Say this to the user when you report completion, so they know what they have.

This is a **v25-era rebuild**. The skill it is reconstructed from continued to change after
the monolith was frozen on 2026-08-10. Not included:

1. **Parallel Phase 1.** The newer skill splits Phase 1 across three agents over a
   partitioned manifest and merges with a reconcile agent. Deliberately dropped -- see
   section 5.
2. **The insider-admin cap escape.** The L3/L4 likelihood cap has two escapes, path and
   gain. A legitimate admin who turns malicious satisfies neither by construction: they were
   granted L4 (no path), and abusing their own privilege adds no reach (no gain). The insider
   threat is about ACCOUNTABILITY -- separation of duties, dual control, an audit trail the
   admin cannot edit -- so a reach-based test misses it structurally. A third escape written
   against the missing accountability control is designed but not built.
3. **L3 defined in serverless terms.** L3 is described only in Kubernetes nouns ("a shell in
   a pod, a database client, a host account"). A serverless or managed-services application
   has no L3 at all, so Phase 2B improvises a classification that then decides exclusion.
4. **A ledger reason for a falsified path.** The Excluded Threats Ledger has a closed set of
   ten exclusion reasons, and none of them says "the asserted flow does not exist."
   `Fully mitigated` is the nearest and it is wrong -- it records a control that was never
   verified, and the partner code audit consumes those rows.
5. **Removal of the Confidence column.** `Confirmed` / `Likely` asserts a level of confidence
   the method cannot support, and its removal has been decided but deferred until after a
   field run. It is retained here, and `check-threats.ps1` still validates it, because
   removing it mid-rebuild would change the schema in an unvalidated way. Note that the HTML
   report renders `Confirmed` in a confident green with no definition anywhere the reader
   sees.

Items 2 through 5 are known gaps in the methodology itself, not defects introduced by this
rebuild. They are listed so that a threat model run here is read with them in mind.

# STRIDE skill repair -- one pass

Copy this whole file to the machine holding the rebuilt STRIDE threat-model skill and give it
to Claude Code with the skill directory in reach. It is entirely self-contained. Do not
consult the monolith prompt for anything in here -- reconstructing from the monolith is the
mistake this file corrects.

Work through Part 1 in order. Parts 2 and 3 are material Part 1 refers to. Part 4 is how you
prove it worked.

## What is wrong, and why

The skill was rebuilt by carving a monolithic source prompt. That premise was wrong. The
monolith is an EARLIER, THINNER document, and several of the skill's files are not derivable
from it at all -- they were rewritten when the skill was built, not carved. Measured file by
file against the real skill:

    phase-0-discovery.md    13% of its content exists in the monolith
    phase-4.md              13%
    phase-0.md              42%

So the rebuild silently produced short versions of those three. Nothing reports this; the
files look complete. `phase-0-discovery.md` matters most: SKILL.md calls it the reading-heavy
heart of the workflow, and a shallow discovery caps the entire run without any downstream
check noticing.

Two further problems come from the same carve:

- **Phase 4 calls scripts that do not exist.** `render-drawio.ps1` and `validate-drawio.ps1`
  were never built, so Phase 4 produces no diagrams at all.
- **The monolith was written for a different harness and for ONE linear agent.** It names
  Continue.dev tools, tells each phase to update `STATE.md`, and tells it to wait for the user
  to type `proceed`. In this skill the phases are SUBAGENTS: they cannot talk to the user, and
  `STATE.md` belongs to the orchestrator alone -- four subagents run in parallel at Phase 3.

## Part 1 -- do this, in order

### Step 1 -- replace three files, verbatim

Part 2 contains three complete files. Write each to the path in its BEGIN marker, overwriting
what is there. Content exactly as given, between the markers; the markers are not part of any
file. Do not reformat, re-wrap, merge with the existing version, or preserve anything from it.

    references/phase-0.md
    references/phase-0-discovery.md
    references/phase-4.md

**Then make two edits to `phase-0.md` only.** These files come from a skill whose Phase 1 runs
as three parallel agents over a partitioned file manifest. This skill runs Phase 1 as ONE
agent, so two scripts that version depends on do not exist here. `phase-0-discovery.md` and
`phase-4.md` need no such edits -- every script they name does exist.

1. **`partition-manifest.ps1`** -- one reference, in the last step of the file, telling the
   orchestrator to build the Phase 1 partition manifest after the Scope Proposal is approved.
   Delete that instruction. There is nothing to partition: Phase 1 is dispatched as a single
   agent that runs passes 1A, 1B and 1C in order.
2. **`archive-compare.ps1`** -- one reference, in the step that compares this run's discovered
   resources against the most recent archived run. Delete that step. The script does not exist
   and on a first run there is no archived run to compare against.

Delete the surrounding instruction, not just the script name -- a step that says "run the
comparison and write up the four sets" is not repaired by removing the word it invokes.

Everything else in `phase-0.md` stays exactly as given: it names `init-workspace.ps1`,
`manifest.ps1` and `readset.ps1`, all of which this skill has.

### Step 2 -- build the two Phase 4 scripts

Build `scripts/render-drawio.ps1` and `scripts/validate-drawio.ps1` to the specification in
Part 3. They do not exist yet and are not copied from anywhere.

### Step 3 -- prove the renderer by LOOKING

Do Part 3 section 11 in full: render its sample, open the diagram, and check it item by item
against step 4 of that section. Report what you SAW. "It rendered without error" does not
answer "does any edge cross a component".

### Step 4 -- sweep the carried-over instructions

The three files from Step 1 are clean. The rest of the skill is still carved, so sweep it.
Grep the whole skill directory for each pattern and fix every hit. A pattern returning nothing
is a pass -- report it as such rather than skipping it silently.

Tool names from the other harness -- mechanical replacement:

| Find | Replace with |
|---|---|
| `read_file` | the Read tool (common.md rule R) |
| `create_new_file` | the Write tool (common.md rule W) |
| `single_find_and_replace` | the Edit tool (common.md rule W) |
| `Continue.dev` | remove; the harness is Claude Code |
| `Operating Rule 6` | rule R |
| `Operating Rule 7` | rule W |
| `Operating Rule 7(a)` or `7(d)` | rule W or rule W-d |

Rewrite the surrounding sentence so it still reads correctly. Do not leave a sentence whose
grammar assumed the old tool name.

Orchestration -- this is the half that matters:

`update STATE.md` -- exactly ONE occurrence is legitimate, the one in `phase-0.md`, because
Phase 0 runs in the orchestrator's own session rather than a subagent. Every other occurrence
is in a subagent file and must go. Replace each with an instruction to report the same
information in its completion summary instead -- the orchestrator needs it, so hand it over
rather than dropping it. For example, where the text says

    update STATE.md: mark phase-2b: complete with timestamp, set Last Completed Step,
    set Resume Instruction to "Begin at Phase 2C ..."

write instead

    Do NOT write STATE.md -- it is orchestrator-owned (common.md rule X). In your completion
    summary report: phase-2b complete; the last completed step; and the rehydration files
    Phase 2C will need.

`proceed` / `wait for the user` / `NEW session` -- the source prompt has each phase stop and
wait for the user. A subagent cannot ask the user anything, so an instruction to wait is an
instruction to hang. Delete every one in a subagent file. The orchestrator's gates replace
them and are already defined in SKILL.md.

`Phase discipline` or "execute phases strictly in order" -- if any phase file still carries
this, delete it. Sequencing is the orchestrator's job, defined in SKILL.md's dispatch table.

### Step 5 -- verify, and report every result separately

1. **The manifest.** Part 4 lists the expected line count, byte count, and first and last
   non-blank lines of each file from Step 1. Report the ACTUALS for all three. A short file
   is the likely failure and it is silent.
2. **The sweep.** Re-run every grep from Step 4. All must return nothing, except
   `update STATE.md`, which must return exactly ONE hit, in `phase-0.md`.
3. **The design-level rename.** Grep the whole `references/` directory for `architecture-level`,
   case-insensitively. It must return NOTHING. If it returns hits, the rebuild's post-v25
   correction did not fully land: the current methodology calls this the DESIGN-level test, and
   the older wording discards design decisions that no SAST tool finds. Replace every hit with
   `design-level` and check that no sentence still says a threat must be architectural.
4. **Section 4a Actors.** `phase-4.md` needs every `A-NNN` actor from inventory Section 4a for
   the context diagram, and says plainly that an empty Section 4a means that diagram is WRONG
   rather than empty. Confirm `phase-1.md` defines a `## 4a. Actors` section in its
   Architectural Inventory schema. If it does not, say so prominently -- Phase 4 cannot draw a
   correct context diagram without it, and that is a Phase 1 defect.
5. **The two deleted script references.** Grep the whole skill for `partition-manifest` and
   `archive-compare`. Both must return NOTHING -- they are the Step 1 edits to `phase-0.md`,
   and a surviving hit means the file now invokes a script that does not exist.
6. **Dangling references.** Grep for `render-drawio`, `validate-drawio` and `04-diagram-data`.
   Every hit must now resolve to something that exists. Check `SKILL.md` especially: its Phase
   4 duty expects the validator's output in the returned banner, and its run-end duty prints
   the Archiving Reminder from the end of `phase-4.md`.

### What this does NOT fix

Two files could not be repaired mechanically, because the rebuild merged them and a drop-in
replacement is impossible: `phase-1.md` is missing the `Element Classification` block and the
rule that attested in-path elements from Q3 and Q6a are components; `phase-3.md`'s stakeholder
explainer is thinner than the real one. Both degrade output quality. Neither silently caps
coverage the way discovery does. Report them as known-open rather than attempting a fix.


---

## Part 2 -- files to write verbatim

Everything between a BEGIN marker and its matching END marker is one complete file.

===== BEGIN FILE: references/phase-0.md
<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

# Phase 0 -- Initialization and Scoping (ORCHESTRATOR-RUN)

**Goal:** Derive inputs, validate the workspace, set up the output directory, prevent it from being committed to the source repo, initialize STATE.md, and produce a scope proposal for user review.

**Steps:**

1. **Initialize the workspace (one script call).** This single script derives the run's values, validates the workspace, creates the output tree, adds the git exclude, lists prior archived runs, and prints the top-level repo map -- it is steps 1, 2, 3 and 5's listing in one call. Run it and print its complete output so the user can confirm. Use the invocation form for YOUR shell (common.md rule S -- if your shell is bash, use the `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` form):
   ```powershell
   & '<SKILL_DIR>\scripts\init-workspace.ps1'
   ```
   Run it with no arguments the first time so it derives the workspace from the current directory, OR pass them explicitly if you already know them:
   ```powershell
   & '<SKILL_DIR>\scripts\init-workspace.ps1' -Workspace '<workspace path>' -ProjectName '<project name>'
   ```

   ASSERTION: OUTPUT_ROOT is ALWAYS the canonical, unsuffixed name `{PROJECT_NAME}-threat-model` -- computed only from $WORKSPACE and $PROJECT_NAME as shown above, never from anything printed by the archived-runs listing. Any sibling directory matching `{PROJECT_NAME}-threat-model-<suffix>` (a date suffix, e.g. `{PROJECT_NAME}-threat-model-20260601`) is a PRIOR ARCHIVED RUN, created by the end-of-Phase-4 archiving step (see the Archiving Reminder in phase-4.md), not the current run. This run must never write into an archived directory and must never treat one as the current OUTPUT_ROOT -- the block above lists any that exist purely so the orchestrator can see them (and so step 7.7 below can compare against the most recent one); it does not target them. SKILL.md's Session Start applies the same rule to resuming: an archived `-yyyyMMdd` directory is never a resume target even if it still holds its own STATE.md from when it was the active run.

   This script is the ONLY place in this run that derives WORKSPACE from the current directory. Note its printed WORKSPACE and PROJECT_NAME values (and the SKILL_DIR path given in SKILL.md) as literal strings now -- every later step substitutes them as literals instead of re-deriving them.

   Shell state does not persist between tool calls (common.md rules W and S): variables AND the working directory are both gone in the next call, so every later call passes these values explicitly. Never re-derive WORKSPACE from `(Get-Location)` in a later step -- a wrong value silently writes this run's artifacts into a different repository. Where a later step still shows an inline PowerShell block, it carries this prelude:
   ```powershell
   $WORKSPACE    = '<the literal WORKSPACE path printed in step 1>'
   $PROJECT_NAME = '<the literal PROJECT_NAME printed in step 1>'
   $OUTPUT_ROOT  = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"
   $SKILL_DIR    = '<the literal SKILL_DIR path given in SKILL.md>'
   ```
   Substitute all three literal paths -- WORKSPACE and PROJECT_NAME from step 1's printed output, SKILL_DIR from SKILL.md (the directory containing it). If your shell is bash, do not paste such a block into it: write it to a temp .ps1 and run it with the -File form (common.md rule S).

   If `PROJECT_NAME` does not match what the user expects (e.g., they opened a parent folder by accident), STOP and ask them to re-open the correct workspace before continuing.

2. **Confirm the output directory tree.** Step 1's script created `{PROJECT_NAME}-threat-model/` with `diagrams/` and `outputs/` subdirectories; its output lists them. Confirm they appear. If OUTPUT_ROOT is not the canonical unsuffixed path, stop and re-check the WORKSPACE value before doing anything else.

3. **Confirm the git exclusion.** Step 1's script added the repo-local exclude entry `{PROJECT_NAME}-threat-model*/` to `.git/info/exclude`. This keeps threat model artifacts out of any commit, diff, or PR against the source repo without modifying a file that would itself need to be committed (important at a regulated org where modifying `.gitignore` may require code review). The pattern is a WILDCARD, not an exact name, because the Archiving instructions (end of Phase 4) rename this directory with a date suffix (`{PROJECT_NAME}-threat-model-yyyyMMdd`) for reuse across runs -- an exact-name entry would stop covering the directory the moment it is archived, silently exposing it to `git status` and a future accidental `git add`. The script prints the resulting `git status` for the output directory: if it lists files (current OR any archived `-yyyyMMdd` copy), the exclude did not take effect -- warn the user before proceeding.

4. **Initialize STATE.md** with the Write tool: all phases pending per the STATE.md schema in SKILL.md, LAST_UPDATED set to the current ISO 8601 timestamp, Resume Instruction = "Begin at Phase 0."

5. **Classify the repo from the top-level map.** Step 1's script already printed the full top-level listing (dirs and files, excluding `.git` and this workflow's output directories) under `=== TOP-LEVEL REPO MAP ===` -- use that output; do not re-list. Classify the repo as one of: `single-service`, `monorepo-multi-service`, `library`, `infrastructure-only`, `mixed`. Apply this decision table IN ORDER, first match wins -- do not classify by feel:
   1. Two or more independently deployable services (separate build/deploy manifests -- e.g. sibling service dirs each with their own Dockerfile / package.json / go.mod / pom.xml) -> `monorepo-multi-service`
   2. No application entry point at all -- only IaC (`*.tf`, k8s manifests, pipelines) -> `infrastructure-only`
   3. A build file that publishes a package/artifact for other code to import, and no runnable service entry point -> `library`
   4. Exactly one deployable application (one entry point / one deploy manifest) -> `single-service`
   5. Anything else (runnable app + substantial IaC for OTHER systems, app + published library, etc.) -> `mixed`
   Record the classification and which rule fired in 00-scope.md.

5a. **Produce a COMPLETE recursive file manifest** -- this is the ground truth Phase 1 must account for, and it is what makes a single run's coverage self-evident instead of only knowable by comparing against a prior run. Enumerate every file (paths only -- no reading, so this is cheap even on large repos), excluding the tool-state and vendored directories that never generate threats:
   Run the extracted script and paste its output:
   ```powershell
   & '<SKILL_DIR>\scripts\manifest.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
   ```
   Record the total file count. Write the manifest to `00-file-manifest.txt` (one relative path per line). Phase 1 will assign EVERY file in this manifest to a component or a justified skip-bucket, and reconcile the totals -- so a file that gets silently overlooked becomes a visible rule violation, in this single run, with no prior run required to notice it. If the count is very large (thousands of files), still write the full manifest; the accounting in Phase 1 rolls low-relevance files into counted buckets rather than reading each.

6. **Pre-flight questions -- STOP AND PROMPT USER**

   DO NOT PROCEED UNTIL THE USER ANSWERS ALL QUESTIONS BELOW.

   ASK THEM AS WRITTEN, AND ACCEPT THE ANSWERS. Put each question to the user in the words below -- do not paraphrase it, do not compress several into one, and do not invent answer options for a question that does not have them (Q3, Q4 and Q6a are FREE TEXT; only Q1, Q2 and Q6 offer choices). Then RECORD what the user says, verbatim, and move on. Do not challenge, re-ask, or second-guess an answer, and do not ask the user whether they are sure: their answers are ATTESTED FACTS under Operating Rule 2 -- evidence in their own right, supplied by the person who actually knows this system's deployment. You have read nothing at this point, so you have no basis to doubt them and nothing to doubt them with. The ONE place an answer is ever measured against evidence is step 7.6, AFTER discovery, and even there the output is a recorded verdict surfaced at GATE 1 for the user to adjudicate -- never an interrogation here. (Verification posture belongs to subagent OUTPUT, never to the user's inputs.)

   First offer the fast path: "If you have a prepared INPUT PROFILE (answers to Q1-Q6a below), paste it now and I will only ask for anything it does not cover. Otherwise I will ask each question in turn." If the user pastes a profile, parse it, echo back the parsed answers for confirmation, and ask individually ONLY the questions the profile left unanswered. Profile answers are user-attested facts exactly as if given interactively, and are recorded identically (STATE.md User Inputs + 00-scope.md).

   Otherwise, ask the following questions in order. Wait for all answers before continuing.

   Q1: "How is this application exposed?"
   - Internet-facing (public internet access)
   - Internal (corporate network/VPN only)
   - Hybrid (mixed exposure)
   - Unknown/Unclear

   Q2: "How would you rate the criticality of this application?"
   - Critical (breach would cause severe business, regulatory, or safety impact)
   - High (breach would cause significant operational or reputational damage)
   - Moderate (breach would cause limited, recoverable impact)
   - Low (breach would have minimal impact)
   Use the criticality rating to inform likelihood scoring (Critical/High apps are higher-value targets attracting more sophisticated attackers) and to frame mitigation urgency in recommendations. Do NOT use it to suppress or filter findings.

   Q3: "List any mitigating controls already in place (WAF, API gateway, CDN, IDS/IPS, MFA, etc.):"
   (e.g. Cloudflare WAF, Okta SSO -- or 'none' if none)
   Q3 answers are user-attested facts (Operating Rule 2), with the CONTROL asymmetry that rule defines: an attested control renders in SecurityControl as `Attested -- <control> (unverified in code)` and may be credited in ResidualRisk, but without corroborating code/IaC evidence it may never justify a `Fully mitigated` exclusion, discharge the data-flow obligation, or lower a Likelihood below the inclusion gate -- a candidate suppressed only by an attested control goes to the Excluded Threats Ledger as `Attested-mitigated (unverified)`.

   Q4: "What is the sensitivity of the data the application handles?"
   (e.g. PII / PHI / financial data / internal config only / public data)

   Q5: "Mitigation recommendations will use NIST 800-53 Rev 5 as the governance framework. Press Enter to accept, or name a different framework or compliance requirement (e.g. SOC 2, HIPAA, PCI-DSS, GDPR) to override."
   If the user accepts the default or gives no answer, GOVERNANCE_FRAMEWORK = NIST 800-53 Rev 5.

   Q6: "Is the runtime infrastructure -- container platform / cluster (e.g. Kubernetes, EKS), cloud IAM roles and policies, and the CI/CD pipeline -- managed by THIS application team, or provided as a managed platform by a separate team this application team cannot modify?"
   - (a) This team manages it -> INFRA_OWNERSHIP = SELF-MANAGED. Infrastructure-as-code in this repo is in scope; assess it normally.
   - (b) Separate platform team; this app team cannot modify it -> INFRA_OWNERSHIP = PLATFORM-INHERITED. Ask follow-up Q6a below, then apply these scoping rules: the cluster, the IAM baseline, and the pipeline are inherited controls assessed elsewhere (ideally a separate threat model run against the platform repo). Do NOT enumerate threats against the platform's own internal configuration, and do NOT hypothesize the permissions of principals or policies that are not defined by a file in this repo. Two things remain FULLY in scope: (1) the application's own side of every data flow -- its listeners, ports, client configurations, and TLS material are files in THIS repo, so a plaintext listener sitting behind the platform's TLS-terminating proxy is an app-evidenced exposure, not a platform finding; every data flow has two ends, and the app's end is always in scope; (2) exposures the user attests in the Q6a platform profile. Emit an infrastructure or IAM threat only when it is grounded in one of those two evidence sources; reliance on unattested platform behavior goes to the Assumptions Log.
   If the answer is unclear, default to PLATFORM-INHERITED and note the uncertainty -- the conservative choice, since it suppresses unevidenced platform findings while still surfacing app-evidenced and user-attested exposures.

   Q6a (ask only when Q6 = PLATFORM-INHERITED -- FREE TEXT, no answer options: ask it open-ended and take whatever the user describes, including "unknown"): "Describe the platform's standard traffic path for this application and where TLS terminates (e.g., 'Akamai WAF -> reverse proxy -> app container; TLS terminates at the proxy; plaintext HTTP from proxy to container'). Include anything else the platform imposes that affects this app's security posture (network segmentation, service-mesh mTLS, egress restrictions) -- or answer 'unknown'."
   The answer is the ATTESTED PLATFORM PROFILE: user-supplied facts treated as citable evidence per Operating Rule 2, cited as `[evidence: user-attested, Phase 0 Q6a]`. Together with Q3's existing controls it has two faces, and the model MUST use both -- but they carry ASYMMETRIC force (Operating Rule 2): attested EXPOSURES (e.g., the plaintext hop after TLS termination) carry full evidentiary force and ground threats in the main table even in PLATFORM-INHERITED mode; attested CONTROLS (e.g., the WAF absorbs volumetric DDoS) feed SecurityControl (as `Attested -- ... (unverified in code)`) and ResidualRisk credit, but never solely justify a fully-mitigated exclusion -- a candidate suppressed only by an attested control is recorded as `Attested-mitigated (unverified)` in the Excluded Threats Ledger, where the code audit picks it up as a verification lead. Attestation is evidence, not speculation. If the user answers 'unknown', record that in the Assumptions Log and proceed without a topology profile.

   Record all answers in STATE.md under a ## User Inputs section and include them in 00-scope.md. (The exposure answer is validated against discovery evidence in step 7.6, after the sweep has run -- not here, where nothing has been read yet.)

7. **EXHAUSTIVE DISCOVERY -- dispatch the discovery subagent.** This is the highest-leverage step in the workflow, and it is the one step of Phase 0 that does NOT run in your session: deep reading needs a full, dedicated context window, and running it here would make it compete with orchestration and user dialogue (a model managing a conversation economizes on reading -- a field-observed failure). Dispatch ONE general-purpose subagent per SKILL.md's dispatch table, briefed on `references/phase-0-discovery.md`. It runs Pass 1 (source investigation), Pass 2 (mechanical sweep), the refinement, and the completeness self-audit, and it writes `00-discovery.md`, `00-discovery-raw.txt`, `00-density.txt`, and `00-candidates.txt`.

   When it returns, RUN THE READ-SET VERIFICATION YOURSELF -- do not read its verdict off the agent's summary (SKILL.md sets out why at length; the short version is that a field run fabricated one). Use YOUR shell's invocation form per common.md rule S:
   ```powershell
   & '<SKILL_DIR>\scripts\readset.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>' -Verify
   ```
   Then verify before continuing: `00-discovery.md` exists and is non-trivial; `00-files-read.txt` exists and lists the files reviewed; and the VERDICT line the command YOU just ran says COMPLETE. If it says INCOMPLETE, or its reading accounting shows it read only a handful of files, or the refinement rescued several candidates Pass 1 missed, RE-DISPATCH it with the shortfall named -- do not proceed to scope on a shallow discovery, because nothing downstream will catch what it missed. Paste the command's output and the agent's returned discovery summary.

7.6. **Exposure validation (mandatory, after the sweep, before writing 00-scope.md).** Validate the user's Q1 exposure answer against what the sweep and repo map actually surfaced: ingress/edge references (public hostnames, LB/WAF/CDN references, `0.0.0.0` binds, Ingress resources or internet-facing IaC if present in this repo). This is a consistency check on attested facts, not a re-derivation. Record a one-line verdict for 00-scope.md: `Exposure validation: Q1=<answer>; discovery evidence <consistent | CONFLICT: <what the evidence shows>>`. A CONFLICT verdict MUST be surfaced in the step 9 Scope Proposal for the user to adjudicate (the user may know infrastructure this repo cannot show); record their ruling in 00-scope.md. Under PLATFORM-INHERITED infra, thin edge evidence in the repo is normal and is NOT a conflict -- flag a conflict only when found evidence positively contradicts the answer.

7.7. **Write 00-resources.txt (ALWAYS), then archive comparison (completeness cross-check, only when a prior archive exists).** This step has two parts. Part 1 is UNCONDITIONAL and runs on every assessment, including a first run with no prior archive; only Part 2 (the comparison) is gated on a prior archive existing. Do not skip Part 1 just because this is a first run.

   Part 1 (always): write `{PROJECT_NAME}-threat-model/00-resources.txt`: this run's own final DISTINCT resource list in machine-readable form, one per line, two tab-separated columns: `type<TAB>canonical name`, where type is one of `bucket|table|database|queue|topic|cache|agent|external-api|identity-provider|secret-store|service|other`. CANONICAL NAME FORMAT (pin this exactly, or cross-run comparison produces false diffs): the canonical name is the BARE resource identifier as it literally appears in the code or IaC -- the actual bucket name, table name, queue name, hostname, or service id -- lowercased, with NO type word or prefix (write `filings-documents`, never `s3 filings-documents` or `bucket:filings-documents`; the type lives in its own column), NO surrounding quotes, and NO environment decoration added or stripped beyond what the identifier literally contains. One line per distinct resource. Sort the file. This exact-string discipline is what lets a later run's `Compare-Object` detect real drift instead of formatting noise. Its line count MUST equal the distinct-list count in 00-discovery.md (state both, per Operating Rule 15). It is written here, before the comparison below, so this step (and every future run's comparison) has this run's own list on disk -- step 8 below no longer writes it (see the note in step 8).

   Part 2 (only when a prior archived run exists): compare this run's 00-resources.txt against the most recent archive, as follows.

   Run the comparison script (one call; use YOUR shell's invocation form per common.md rule S):
   ```powershell
   & '<SKILL_DIR>\scripts\archive-compare.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
   ```
   It finds the most recent archived run, picks the comparison basis (the archive's `00-resources.txt`, or its `01-inventory.md` element names as a weaker name-only fallback, or reports that it cannot be compared), and prints the FOUR sets described below plus both resource counts. If no archive exists it says so and you skip to step 8 without writing 00-archive-comparison.md. Paste its output.

   Write the result to `{PROJECT_NAME}-threat-model/00-archive-comparison.md` with the Write tool (common.md rule W): which archived run was compared (name, LastWriteTime), the comparison basis (00-resources.txt name column, the 01-inventory.md fallback, or "could not be compared" with the reason), and the FOUR named sets in full, not just counts -- (1) in prior/not in current (DISCOVERY drift / possible regression), (2) in current/not in prior (new), (3) same name/different type (CLASSIFICATION drift -- the same resource re-binned, e.g. a fetched-from source corrected from data-store to external-api; NOT a missed resource), and (4) unchanged. This is a completeness cross-check, not an auto-merge: never silently pull a prior run's resource into this run's scope on the strength of this comparison -- every "in prior, not in current" item is surfaced as a question for the user, never merged in automatically.

   The "in prior, not in current" set is a possible completeness REGRESSION (something the prior run found that this run missed) or a legitimately removed/decommissioned resource -- either way it MUST be investigated or explained before scope closes, so it is REQUIRED to also appear in the step 9 Scope Proposal as an explicit question for the user to adjudicate at GATE 1: the user may know a resource was decommissioned, or may recognize a real miss that sends discovery back for another look. Record the user's ruling on each item in 00-scope.md.

8. **Write a scoping note** to `{PROJECT_NAME}-threat-model/00-scope.md`. PRECONDITION (do not write this file until all of it holds): steps 7 (both passes + refinement), 7.5, 7.6, and 7.7-Part-1 have completed and their artifacts exist on disk -- `00-discovery.md`, `00-discovery-raw.txt`, `00-candidates.txt`, `00-density.txt`, and `00-resources.txt`. 00-scope.md is a synthesis OF those artifacts; writing it before they exist produces a scope guessed from memory, not derived from discovery (a field-observed failure). If any artifact is missing -- e.g. the sweep did not finish -- STOP and complete discovery first; do not write a partial scope. The note captures `PROJECT_NAME`, `WORKSPACE`, the detected repo type (and which classification rule fired), languages/frameworks with evidence, deployment exposure (from step 6) with the step 7.6 exposure-validation verdict line, the data stores and external integrations -- every distinct item from 00-discovery.md triaged as in-scope or out-of-scope-with-reason (nothing from the sweep silently absent), split into IaC-defined (schema/config in this repo's infrastructure files) and runtime-referenced (named in application code but not in this repo's IaC; cite the referencing source file) so the code-vs-IaC provenance is visible, the infrastructure ownership mode (Q6: SELF-MANAGED or PLATFORM-INHERITED -- and when PLATFORM-INHERITED, state explicitly that the platform's internal configuration is inherited and assessed elsewhere, reproduce the Q6a attested platform profile verbatim so later phases can cite it, and note that the app's side of every data flow plus attested exposures remain in scope), in-scope components, and explicit out-of-scope items (e.g., vendored third-party code under `node_modules/`, `vendor/`, `target/`, `.venv/`; tool-state directories such as `audit_state/` from the CodeSecurityAudit prompt and `{PROJECT_NAME}-threat-model/` from this prompt's own prior runs). Every item in this list is MANDATORY: a scope note missing any of them is a rule violation, not a style choice. Classify each data store vs external integration by the DS-vs-EXT ownership test (Phase 1 output schema, Section 3) -- the operator question: content this system owns = data store even on managed infrastructure; service another party operates with this system as client = external integration even if this system only fetches data from it (a scraped/fetched-from remote source is an EXT, never a data store -- the fetch trap; the place fetched data lands is a separate DS). Achieve brevity through terseness per item, never by omitting an item -- Operating Rule 9's token budget governs reading, not this file's completeness. Write the file with the Write tool (common.md rule W).

   `{PROJECT_NAME}-threat-model/00-resources.txt` was already written in step 7.7, before the archive comparison that step performs against it. This is the cross-run comparison artifact: any later run (or a second pass of this one) is unioned against it with `Compare-Object (Get-Content run1) (Get-Content run2)` -- so both discovery drift AND classification drift between runs become visible mechanically. Confirm here that its line count still equals the distinct-list count in 00-discovery.md (state both, per Operating Rule 15); do not rewrite it unless that count is wrong.

9. **Print a Scope Proposal.** OPEN IT WITH A DISCOVERY COVERAGE BLOCK, before the scope contents. GATE 1 is the user's one chance to reject a shallow discovery before four phases are built on it, and they cannot judge that from a component list -- they need to see how much was actually read. Reproduce, verbatim, the `readset.ps1 -Verify` output from the run YOU performed in step 7 (the per-class enumerated / read / unread table and its VERDICT line), plus the application-signal-file reconciliation and the count of rescued candidates Pass 1 missed. Then state one plain-language line the user can act on, e.g. `Discovery read 214 of 214 required files across 6 classes; 0 unread; 2 candidates were rescued by the sweep that Pass 1 had missed.` If the verdict is anything but COMPLETE, or rescued-missed is more than a couple, SAY SO FIRST and recommend re-running discovery rather than approving -- do not bury it under the scope contents. Never hand the user a command to run: you have already run the verification yourself, and the coverage block is your report of what it returned. Lead with the plain-language line -- the user should be able to accept or reject the discovery without reading a table or knowing what a read set is.

   Then present the same information from step 8 plus any ambiguity that requires a user decision (multi-service monorepo -- which service? unclear scope boundaries?), any step 7.6 exposure-validation CONFLICT stated explicitly as a question for the user to adjudicate, and -- when step 7.7 found a prior archive -- its "in prior, not in current" set stated explicitly as a question for the user to adjudicate (regression or legitimate removal). This is the proposal the user reviews before Phase 1 begins.

10. **Update STATE.md.** Mark `phase-0: complete` with the current timestamp, set Last Completed Step to `phase-0 -- scope proposal written to 00-scope.md`, set Resume Instruction to `Begin at Phase 1 (Documentation, Diagram, and Source Analysis).`

**Phase 0 Completion Banner:**
```
=== PHASE 0 COMPLETE: SCOPE PROPOSAL READY ===
WORKSPACE    = <path>
PROJECT_NAME = <name>
OUTPUT_ROOT  = <path>\<name>-threat-model
Output directory excluded from source repo git tracking: [yes/no]
Scope file written: <name>-threat-model\00-scope.md
File manifest written: <name>-threat-model\00-file-manifest.txt (<N> files -- Phase 1 will account for every one)
Pass 1 investigation: <N> of <N> source files read | docs read IN FULL <N> of <N> (must be equal) | entry points: <list> | <N> resources found
Pass 1 read-set verify: <COMPLETE | INCOMPLETE -- N floor files unread>  (tool-computed by readset.ps1 -Verify, run by the ORCHESTRATOR)
Application signal files: <N> | accounted (read+bucketed): <N> | unaccounted: 0
Rescued candidates Pass 1 missed: <N> (0 = passes agree; high = reading was thin)
Pass 2 sweep: <N> candidates (tool-computed) | refinement: <N> accounted, <N> rescued | top-10 density read: <10/10>
Resources: <N> written to 00-resources.txt (line count matches distinct list: yes)
Exposure validation: <consistent | CONFLICT -- see Scope Proposal>
Archive comparison: <no prior archive | compared vs {name}: <N> new, <N> only-in-prior (see Scope Proposal)>
STATE.md updated: phase-0 marked complete.
Present this Scope Proposal to the user and wait for approval or corrections (GATE 1).
```

---

After the user approves the Scope Proposal, run `& '<SKILL_DIR>\scripts\partition-manifest.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'` (your shell's form per common.md rule S) and paste its reconciliation line. The three partition files drive the parallel Phase 1 passes.
===== END FILE: references/phase-0.md

===== BEGIN FILE: references/phase-0-discovery.md
<!-- SKILL VERSION: v25-skill (2026-07-24g) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

# Phase 0 Discovery -- Exhaustive Element Discovery (SUBAGENT)

You are the Phase 0 DISCOVERY agent. You have a full, dedicated context window and ONE
job: find every architectural element this repository contains or references. Nothing
else competes for your attention -- no user dialogue, no orchestration, no later phases.
USE THAT BUDGET. Reading deeply is the work; a run that finishes quickly on a large
repository has failed, not succeeded.

Everything downstream inherits what you find here. A resource you miss is not threat-
modeled at all: it will not appear in the inventory, will get no STRIDE walk, and will
be absent from the final report -- silently, with no reconciliation anywhere catching it.
This is the single highest-leverage step in the entire workflow.

Read your rehydration inputs first: 00-scope.md does not exist yet, so your inputs are
STATE.md (for the run's user-supplied answers) and 00-file-manifest.txt (the authoritative
list of every file in scope). Write your output to 00-discovery.md plus the sweep
artifacts named below.

## Your task: identify the primary language(s), framework(s), build system(s), and the concrete elements in scope -- only from files you have directly observed. Look for `package.json`, `pom.xml`, `*.csproj`, `go.mod`, `requirements.txt`, `Cargo.toml`, `*.tf`, `Dockerfile`, `*.yaml` (k8s/helm), etc. Use the Read tool for each detection file and cite with evidence paths relative to the workspace root. "Identify" here means ENUMERATE BY CONCRETE IDENTITY, not "name the stack": list each service/process, each data store, each external integration, each secret location, and each pipeline/workflow you can see at scope level, by its actual name/id -- not a count. A generic quantifier standing in for a list ("several agents", "various services", "multiple buckets", "etc.") is a rule violation, not shorthand: if you are about to write "several X", stop and enumerate every X (use the Grep tool -- or Select-String -- to find them all, then read the relevant ranges; common.md rule R). This is generic to any stack -- the element TYPES are fixed, the instances are whatever this repo actually contains.

   EXHAUSTIVE DISCOVERY -- run BEFORE scope so nothing is excluded by never being found. The highest-miss category is RUNTIME-REFERENCED resources (data stores, buckets/tables, queues, agents, external APIs, secrets the application CODE or DOCS reference but that are NOT in this repo's IaC -- common under PLATFORM-INHERITED infra). Discovery is TWO INDEPENDENT PASSES plus a REFINEMENT -- belt and suspenders by design. The passes use DIFFERENT mechanisms with different blind spots: comprehension (Pass 1) understands everything it reads but cannot read everything; the mechanical sweep (Pass 2) touches everything but understands nothing. Run them independently -- do not let one steer the other -- and merge them in the refinement, where each catches what the other missed.

   PASS 1 -- SOURCE INVESTIGATION. This is the PRIMARY method and where MOST of this phase's effort belongs. Read the source like the security architect you are. Start from the entry points and main modules, follow their imports and references outward, and read deeply -- Operating Rule 9 ranges for files over ~2000 lines, full reads otherwise.

   THE MANDATORY READ SET -- COMPUTE IT FIRST, BEFORE YOU READ ANYTHING. "Read deeply" is not a stopping condition, and a field run satisfied it with SIX files. So your FIRST action in this pass is to run the read-set script, which classifies the manifest into the role-based classes below and writes `00-readset.txt`:
   ```powershell
   & '<SKILL_DIR>\scripts\readset.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
   ```
   (bash shell: use the `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` form, common.md rule S.) That file is your floor. It is COMPUTED, not chosen by you, and every file in it is READ IN FULL.

   AS YOU READ, LOG IT -- THIS IS A DELIVERABLE, NOT BOOKKEEPING. Append every file you read, floor files and investigation files alike, to `{PROJECT_NAME}-threat-model/00-files-read.txt`, one relative path per line. It is the RECORD OF WHAT WAS REVIEWED: without it there is no list of what discovery actually looked at, nothing can be verified, and a reviewer cannot tell a thorough pass from a shallow one. A completion summary that says "read N key files" instead of producing this file is not an acceptable substitute -- write the file.

   THE FLOOR IS SMALL ON PURPOSE, AND IT IS NOT THE WHOLE JOB. It holds only what a
   mechanical pattern cannot substitute for -- where the system starts, how it is configured
   per environment, who it trusts, what it calls out to, and what its authors wrote down.
   Ordinary application source and view files are NOT in it: the Pass 2 sweep reads every one
   of them mechanically, and the density refinement sends you into the highest-signal ones.
   That division is deliberate. Finding an external integration is a pattern problem (a URL
   is a literal string); reading is for what patterns cannot do -- dynamically-built names, a
   resource named only in a comment, and above all UNDERSTANDING how the pieces connect. Read
   the floor completely, then investigate outward as far as the system's structure warrants.

   The read set is achievable BY CONSTRUCTION: high-cardinality classes are signal-filtered by the script (a view or source file with no external reference is deferred, mechanically, and listed in 00-readset-deferred.txt), so the floor is the files that can actually contain an integration -- not every file in the repo. It is meant to be met, not sampled. If the floor still looks large, that is the repo telling you the truth about its integration surface.

   YOU DO NOT ISSUE A VERDICT ON YOUR OWN COVERAGE. Do not write "VERDICT: COMPLETE", "depth:
   adequate", or any verdict-shaped sentence about how much you read -- not even a true one.
   Coverage is a computed fact, not an impression, and the orchestrator computes it by
   diffing 00-readset.txt against your 00-files-read.txt after you return. A field run wrote
   `Verdict: COMPLETE (all critical integration points identified and enumerated)` -- which
   is not this script's output, is a different claim than the one being verified (files read,
   not integrations found), and read as verification while being an opinion. If you find
   yourself composing a sentence that ASSESSES your own thoroughness, stop: that sentence is
   not yours to write.

   WHAT YOU REPORT INSTEAD, as plain facts the orchestrator can check against the artifacts:
   the number of files you read (which must equal the line count of 00-files-read.txt), the
   number of further files you read beyond the floor, and anything you could not read and
   why. Nothing evaluative.

   You may run the verification yourself while working, to find out what you still owe:
   ```powershell
   & '<SKILL_DIR>\scripts\readset.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>' -Verify
   ```
   (bash shell: the `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` form, rule S.)
   Use it as a worklist -- it names the floor files you have not read yet. Keep reading and
   re-running until it stops naming files. But its output is a tool result to act on, not a
   verdict for you to restate.

   The classes the script computes, defined by ROLE rather than any framework's vocabulary -- it matches on whatever your stack calls them:
   - ENTRY POINTS -- however this stack expresses them: `main`/`app`/`index`/`Program`/`Startup`, route or endpoint registration, serverless handlers, queue consumers, scheduled/cron jobs, CLI commands, webhook receivers. Every one, not the first one you find.
   - CONFIGURATION AND ENVIRONMENT FILES, INCLUDING PER-ENVIRONMENT OVERLAYS -- `values-<env>.yaml`, kustomize overlays and patches, `.env*`, `appsettings*.json`, `config/*`, per-env `*.tfvars`, CI/CD environment blocks, ConfigMap/Secret manifests. Read the OVERLAY, not just the base file: an endpoint frequently appears ONLY in the production overlay while the base carries a placeholder or a dev stub. A production-only endpoint is a first-class integration.
   - AUTHENTICATION AND AUTHORIZATION -- any file whose name or path carries `auth`, `oauth`, `oidc`, `saml`, `sso`, `login`, `token`, `jwt`, `session`, `identity`, `principal`, `permission`, `policy`, `guard`, `middleware`. These name the identity providers and trust boundaries the whole model rests on.
   - EXTERNAL CLIENT / INTEGRATION FILES -- names or paths carrying `client`, `gateway`, `adapter`, `connector`, `provider`, `integration`, `api`, `service` where the file talks OUT of this system.
   - CLIENT-SIDE AND VIEW FILES -- templates, views, components, pages, and browser-delivered source (`.html`, `.jsx`/`.tsx`, `.vue`, `.svelte`, Razor/Blade/Jinja/ERB, static JS under a web/public/assets dir). Third-party integrations live here as `<script src>` tags, SDK and widget initialization, analytics and tag managers, payment or auth iframes, map/CDN/font hosts, and browser-direct `fetch`/XHR to a third party. A browser-to-third-party call IS an external integration of this system -- it carries this system's data or identity to another party -- and no server import graph will ever show it to you.
   - ALL DOCUMENTATION, at any depth, in full (`README*`, `*.md`, `ARCHITECTURE*`, `DESIGN*`, `SECURITY*`, `THREAT*`, `docs/`, `doc/`) -- a prose sentence like "integrates with the Acme Payments API" matches no pattern.

   Do NOT sample these classes. There is no "representative subset" of your entry points or your environment overlays -- a floor expressed as a fraction becomes a ceiling, and the class you sampled is the class you half-read. If a class is genuinely too large to read in full (hundreds of view files), read it in full where the sweep shows signal and bucket the remainder BY NAME with a reason, so the shortfall is visible and countable rather than silent.

   Beyond the floor, INVESTIGATE: walk imports outward from the entry points, follow references, and read what the system's own structure tells you matters. The floor guarantees coverage; the investigation is where comprehension finds what no list could name -- dynamically-constructed resource names, a resource mentioned only in a comment, an integration implied by prose.
   THIRD-PARTY SERVICES ENTER AS DEPENDENCIES, NOT ONLY AS URLS. When you read the dependency
   manifests, treat every third-party package that reaches a network or handles this system's
   data as an EXTERNAL INTEGRATION in its own right -- monitoring and APM agents, analytics and
   tag managers, error/crash reporters, payment and auth SDKs, feature-flag and CDN clients,
   email/SMS providers. A package reference contains no scheme, no host and no TLD, so no
   pattern in the sweep can see it; reading the manifest is the only way it is ever found, and
   a monitoring vendor was missed in the field for exactly this reason. Name the vendor and
   cite the manifest line.

   CITE THE SOURCE, NEVER OUR OWN ARTIFACT. Every element's evidence is a `file:line` in the
   REPOSITORY. Never cite `00-hosts.txt`, `00-candidates.txt` or `00-discovery-raw.txt` as the
   evidence for a resource -- those are this run's derived intermediates, not the system. When
   the sweep is what surfaced a resource, open 00-discovery-raw.txt, take the `path:line` it
   records, and cite THAT (reading the line in context first, so you can say what the resource
   is and who uses it).

   Extract every element BY CONCRETE IDENTITY as you go: every service/process, data store, bucket, table, queue, agent, external endpoint, integration, and secret surface the code defines or references. Record every finding with `file:line` (or `doc:section`) evidence.

   THE SWEEP IS NOT A SUBSTITUTE FOR THIS PASS, AND FINISHING FAST IS A FAILURE SIGNAL. Pass 2 runs in seconds and produces tidy artifacts; that tidiness invites the belief that discovery is handled. It is not -- a mechanical pattern cannot recognize a resource it has no literal string for, which is precisely the category that has been missed in field runs. If you find yourself reaching step 7.5 having read only a handful of files, you have skipped this phase's actual work, not completed it efficiently.

   PASS 1 READING ACCOUNTING. Do not hand-write these numbers -- paste the `-Verify` output above, which computes them from 00-readset.txt and 00-files-read.txt. Then add the one figure the script cannot know:
   `Investigation beyond the floor: <N> further files read`
   The depth verdict is NOT yours to assert -- it is the script's VERDICT line. COMPLETE means the floor was read; INCOMPLETE means it was not, whatever your impression of the run. Never write "adequate" over an unrun or failing check.
   A COMPLETE verdict means the floor was read. It does NOT by itself mean the pass was thorough: the floor is the minimum, and the investigation beyond it is where comprehension finds what no file-name rule could ever enumerate.

   Scope: read only what is in 00-file-manifest.txt. The manifest already excludes this workflow's own output, `audit_state*`, `security_architecture_audit.md`, and vendored/generated directories; those are out of bounds for exploratory reads too, not just manifest-driven ones (Operating Rule 13a -- the sole exception is step 7.7, which reads a prior run's `00-resources.txt` only).

   PASS 2 -- MECHANICAL SWEEP (the SAFETY NET, not the method; tool-side, zero judgment, seconds of work). It catches literal strings Pass 1's reading may have walked past. It cannot catch anything else, and it is not evidence that discovery happened. Run it via `scripts/sweep.ps1`, which applies these nine patterns (language-agnostic -- extend per-stack, never shorten) case-insensitively over the manifest. The script handles its own scale mechanics -- it skips bulk-data/binary/generated files and caps candidate harvesting on saturated patterns, all documented in the script header; a `SATURATED` line in its output is expected on a large repo, not an error, and `-MaxFileKB`/`-SaturationCap`/`-CandidateCap` are there if a repo needs tuning. The nine patterns:
   - `://`  (every URI and connection string, any protocol/language: https, postgres, redis, mongodb, amqp, s3, ...)
   - `s3|bucket|dynamodb|sqs|sns|kinesis|rds|redis|kafka|rabbitmq|mongo|postgres|mysql|elastic|queue|topic`  (service names, language-agnostic; extend the list if the stack has others, never shorten it)
   - `secret|password|token|api[_-]?key|access[_-]?key|credential`  (secret/credential surfaces)
   - `\.client\(|\.connect\(|new \w+Client|createClient|connectionString`  (client/connection construction)
   - `_URL|_URI|_HOST|_ENDPOINT|_ADDR|_SERVER|_BROKER|_DSN|_QUEUE|_TOPIC|_BUCKET|_TABLE`  (config/env-var KEYS that wire external services -- CRITICAL under PLATFORM-INHERITED infra, where the endpoint is injected at runtime and only the key appears in the repo; catches integrations no URL/hostname pattern can, e.g. a bucket referenced only as `DATA_BUCKET`)
   - `arn:aws`  (AWS resource identifiers; other clouds use the equivalent -- GCP `projects/.../(topics|subscriptions|buckets)`, Azure `/subscriptions/.../resourceGroups/`)
   - `\b(\d{1,3}\.){3}\d{1,3}\b`  (hardcoded IPv4 endpoints; ignore obvious version numbers)
   - `([a-z0-9-]+\.)+(com|net|org|io|cloud|internal|corp|local|gov|mil|edu|us)`  (bare hostnames referenced without a scheme, incl. `.svc.cluster.local` k8s services and government endpoints like `login.gov`; noisiest pattern -- dedupe and keep only host-like matches; extend the TLD list if the org uses others, never shorten it)
   - `getenv|environ\[|process\.env`  (env-var ACCESS calls -- complements the key-suffix pattern above by catching lookups whose key name matches no suffix, e.g. `os.environ["AGENTS"]`)

   These nine patterns are implemented in scripts/sweep.ps1; to extend them per-stack, note the additions in 00-discovery.md and run the extra patterns yourself (Grep tool, or Select-String), appending their hits to the artifacts.

   Capture everything in variables and write three artifacts -- no display, no `-First` caps (truncation belongs to exploratory reads only, common.md rule R (cap litmus)), no per-line narration; this whole pass is one code block:
   ```powershell
   & '<SKILL_DIR>\scripts\sweep.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
   ```
   Paste its per-pattern counts and candidates line.
   The artifacts: `00-hosts.txt` is the COMPLETE deduplicated list of every host/endpoint the sweep saw, with occurrence counts -- read it in full and account for every host in it; never grep the raw file for hosts and never cap a read of it (common.md rule R). `00-discovery-raw.txt` is every unique match site WITH its path (a bare line divorced from its file turns a real resource reference into an unrecognizable code fragment -- field-proven); `00-density.txt` ranks files by match count; `00-candidates.txt` is every mechanically-extracted name -- match values, quoted no-whitespace literals, and value tokens after `=` or `:` (resource names never contain spaces, so most prose junk dies in the regex, not in your judgment).

   REFINEMENT -- MERGE THE TWO PICTURES (mandatory, before step 7.5). This is where belt and suspenders check each other:
   (a) Density accounting -- TOTAL, not top-N. Use `00-density-app.txt`, the APPLICATION-only ranking (the sweep classifies vendor/generated paths and library filenames out mechanically, because a raw ranking is dominated by third-party libraries full of URLs -- a field run spent its entire "top 10" budget on vendor code and learned nothing). Every file in 00-density-app.txt ends in exactly one of two states: READ (its match sites read in context and its elements extracted -- a full read if it is dense or central) or BUCKETED with a one-line reason (test fixture, generated, sample/demo data, duplicated template). There is no third state and no arbitrary cutoff: a cutoff is what let a real integration sit at rank 11 unread. State the reconciliation: `application signal files: <N> | read: <N> | bucketed: <N> (reasons: ...) | unaccounted: 0`. Unaccounted must be zero. Matches concentrate where resources live -- an unaccounted signal-bearing application file is precisely where a missed integration hides.
   (b) Candidate reconciliation: reconcile every candidate in 00-candidates.txt, but scale HOW you reconcile to the candidate count -- a large repo yields hundreds of candidates even after the sweep's saturation cap, and a row-per-candidate hand-walk does not scale to that. Every candidate ends in exactly one of these dispositions, and the count MUST reconcile (see the tally below), but only the last group needs individual attention:
   - ALREADY-IN-FINDINGS: the candidate is a resource you already found in Pass 1 (exact or clear semantic match). Bulk-count these; do not write a row each.
   - DUPLICATE: a spelling/casing/substring variant of another candidate or finding. Bulk-count.
   - NOISE: mechanically-obvious non-resources -- single common words, language keywords, framework identifiers, file extensions, pure numbers, boilerplate tokens. Bulk-count by this category with a one-line rationale (e.g. "412 noise: language keywords, HTML tag names, and single-word tokens"); do not write a row per noise token. HARD GUARD -- a RESOURCE-SHAPED name may NEVER go in this bucket, however noisy the run: if a candidate contains a dot, hyphen, underscore, slash, or colon, or is camelCase, or reads like an identifier someone provisioned (`prod-filings-docs`, `svc.internal`, `DATA_BUCKET`), it is NOT mechanically-obvious noise -- it goes to PLAUSIBLE-UNKNOWN and gets looked at. This guard exists because the one resource this workflow has missed in field run after field run was exactly that shape, and bulk-dismissal is how a real bucket name disappears without anyone deciding to drop it.
   - PLAUSIBLE-UNKNOWN (the residual that gets individual treatment): a resource-like name (a service/host/bucket/table/queue/endpoint/secret shape) that is NONE of the above. For EACH of these -- and only these -- run a targeted search for that name (Grep tool, or `Select-String -Pattern '<candidate>'`), read the hit in its file context, and decide: real resource (add to findings) or explained-away (state why). NEVER dismiss a plausible-unknown name unread. This residual is normally small even on a huge repo; if it is itself very large, that is a signal the sweep patterns are matching something structural you should investigate as a group.
   Record in 00-discovery.md a triage TALLY (not necessarily a row per candidate): `candidates: <N> (tool-computed) = already-in-findings <A> + duplicate <B> + noise <C> + plausible-unknown <D>` where `A+B+C+D` MUST equal N (state the arithmetic). Write an individual triage row for each of the <D> plausible-unknowns (that table's row count == D), plus the bulk counts for A/B/C. The invariant is preserved -- every candidate is accounted, and the arithmetic proves none were silently dropped -- but only the plausible residual is investigated one by one.
   (c) Note the findings only Pass 1 produced (nothing mechanical could catch them) -- that is comprehension's contribution and the reason both passes exist.
   (d) UNDER-READ SIGNAL -- the self-verification loop. Compare Pass 1's list of external services against the candidates the refinement rescued. Every rescued candidate that turns out to be a real service, endpoint, or provisioned resource AND was absent from Pass 1's findings is evidence that Pass 1 UNDER-READ -- not merely a fact to append. Treat it as a symptom with a location: go to the file where Pass 2 found it, read that file and its neighbours properly, and extract whatever else is there, because a file that hid one integration from you is likely hiding its siblings. State the count: `rescued candidates that Pass 1 missed: <N>`. Zero means the two mechanisms agree and the pass is sound. A non-zero count is the strongest evidence available that reading was too thin -- if it is more than a couple, say so in your summary and go back and read; do not simply carry the rescued items forward and call discovery complete.
   State the refinement result verbatim: `candidates: <N> (tool-computed) | accounted: <N> (=already-in <A> + dup <B> + noise <C> + plausible <D>) | rescued by refinement: <N> | Pass-1-only finds: <N> | top-10 density files read: <10/10>`.

   Write everything to `{PROJECT_NAME}-threat-model/00-discovery.md`: the per-pattern match counts, the Pass 1 source/doc file lists, the candidate triage table, the refinement result line, and the merged DISTINCT list of external services / data stores / endpoints / integrations found (Pass 1 finds + rescued candidates), each with `file:line` or `doc:section`. This file -- not memory or judgment -- is the authoritative "what exists" list that scope triages and Phase 1 inventories. Completeness = both passes run, every candidate triaged (counts stated), every doc read -- shown, not felt.

## Completeness self-audit (mandatory, before you return) For each element category -- services/processes, data stores, external integrations, secrets/credentials, pipelines/workflows -- answer: have I enumerated every instance by concrete identity, or did I summarize with a count or a generic quantifier? If any category is a count or a generic word rather than a full list, go back and read the relevant files until it is a full list. Then RECONCILE against 00-discovery.md: every distinct external service / data store / endpoint the sweep found MUST appear either in your enumerated in-scope elements OR explicitly marked out-of-scope with a reason -- a discovered item that is neither is a silent drop, the exact failure the sweep exists to prevent. State the audit result: `Enumerated by identity: services <yes>, data stores <yes>, integrations <yes>, secrets <yes>, pipelines <yes>; generic quantifiers remaining: <none | list them and fix>; sweep categories run (per 00-discovery.md): <list>; discovered items unaccounted for (neither in-scope nor consciously excluded): <none | list -- rule violation>`. Note the division of labor: Phase 0 establishes the complete SCOPE (which concrete elements exist and are in bounds); Phase 1 builds the full architectural INVENTORY (their relationships, evidence, and file-level accounting) -- Phase 1 owns the deep inventory, but it can only be as complete as this scope, so do not defer enumeration to Phase 1 on the assumption it will backfill what you left generic here. Finally, reconcile against 00-candidates.txt: every candidate the refinement triaged as a resource MUST appear in the scope as in-scope or out-of-scope-with-reason -- a resource candidate that is neither is a silent drop.
===== END FILE: references/phase-0-discovery.md

===== BEGIN FILE: references/phase-4.md
<!-- SKILL VERSION: v26-skill (2026-08-04a) -->

## Phase 4 -- C4 Model and Data Flow Diagrams (draw.io)

### Phase 4 Rehydration (MANDATORY FIRST STEP)

Read STATE.md, 01-inventory.md, and 02-threats.md. Diagrams must be structurally grounded in the inventory (every component, trust boundary, and data flow appearing in a diagram must come from `01-inventory.md`) and annotated with threat IDs from the threat model (every threat ID marker on a diagram must exist in `02-threats.md`).

Read these files with the Read tool (disk content overrides memory): {PROJECT_NAME}-threat-model/STATE.md, {PROJECT_NAME}-threat-model/01-inventory.md, {PROJECT_NAME}-threat-model/02-threats.md.

If either inventory or threats file is missing or empty, STOP and report the error.

Disk content takes precedence over conversation memory. Component IDs (`C-NNN`), trust boundary IDs (`TB-NNN`), data store IDs (`DS-NNN`), external integration IDs (`EXT-NNN`), and threat IDs (`01`, `02`, etc.) must match the IDs in these two files exactly -- do not invent, rename, or re-number any ID.

STATE.md is orchestrator-owned. Do not read-modify-write it.

After reading, acknowledge in one line that you have both files loaded and are ready to generate diagrams.

### YOU WRITE DATA. THE SCRIPT DRAWS.

You do NOT write mxGraph XML and you do NOT compute coordinates. You write ONE data file describing what belongs on each diagram, then run `scripts/render-drawio.ps1`, which emits every `.drawio` file.

This split is deliberate. Layout is roughly fifty coordinates, a dozen four-decimal attachment fractions and a per-edge routing channel, for each of four diagrams. That is arithmetic, an agent doing it by hand on a real system will get some of it wrong, and a single wrong coordinate is a visibly broken diagram. What the diagram should CONTAIN -- which component sits in which tier, which flows exist, which are unprotected, which components a Priority 1 threat touches -- is classification, which is your job and which no script can do.

Everything the script owns, and which you must therefore NOT attempt: page size, the grid of cells every node is placed into (including how many columns a large tier wraps across, and which member goes in which cell), zone container geometry, shape sizes and style strings, edge attachment points, gutter routing and channel allocation, node ordering within the actor and external columns, the legend, and the AI-generation notice. All of it is settled, and all of it was verified by rendering sample diagrams and inspecting the exported images. Do not second-guess it and do not hand-edit the output.

### The data file: `{PROJECT_NAME}-threat-model/04-diagram-data.json`

Write it with the Write tool, in one call, as valid JSON:

```json
{
  "diagrams": [
    {
      "name": "c4-02-container",
      "title": "Container Diagram",
      "nodes": [
        { "id": "C-001", "label": "Web Application", "kind": "component", "tier": "APPLICATION",
          "tech": "Python/Flask", "description": "Serves chart generation requests", "threat": "P1" },
        { "id": "DS-001", "label": "Prod Database", "kind": "store", "tier": "DATA" },
        { "id": "EXT-001", "label": "Bing Maps", "kind": "external", "tier": "EXTERNAL" },
        { "id": "A-001", "label": "End User", "kind": "actor", "tier": "ACTORS" }
      ],
      "edges": [
        { "source": "C-001", "target": "DS-001", "protocol": "TLS/5432", "secure": true, "async": false }
      ],
      "notes": ["C-001 -> APPLICATION tier", "TB-002 reconciled on C-001 -> DS-001"]
    }
  ]
}
```

IDS: USE THE INVENTORY'S, OR A MARKED SYNTHETIC ONE. Every node needs an `id`, and most are inventory ids used verbatim -- `C-001`, `DS-001`, `EXT-001`, `A-001`. But two diagrams legitimately contain elements the inventory does not record, and inventing plausible-looking ids for those makes them indistinguishable from fabrication. Use these instead, and never invent a third form:
- `SYS-001` -- the single block representing THE WHOLE SYSTEM on c4-01. The system as a whole is not a component and has no C-NNN; this is the only node that ever carries it.
- `INT-001`, `INT-002`, ... -- internal elements on c4-03 (layers, middleware, handlers, modules) that are structure INSIDE a component rather than components themselves. Every INT-NNN needs a `file:line` citation in `notes`, per the c4-03 rule below.
A `SYS-` or `INT-` prefix is a promise to the reader that the element is deliberately outside the inventory rather than a lapse, and it lets Validation exclude them from the inventory reconciliation instead of failing the count. If you find yourself wanting an id for something that is neither an inventory element nor one of these two cases, that is the signal that it does not belong on the diagram.

Field rules:

- `kind` is one of `component`, `store`, `external`, `actor` (C4 diagrams) or `process`, `dfdstore`, `external` (the DFD). It selects the shape; you do not supply styles.
- `tier` is one of `ACTORS`, `EDGE`, `APPLICATION`, `DATA`, `SECURED`, `EXTERNAL`, assigned by the decision table below. Column order and containers follow from it.
- `tech` is optional: the technology or framework, rendered on a second line in the C4 convention as `[Container: Python/Flask]`. The type word comes from `kind` -- Container, Process, Database, Data Store, External System, Person -- so supply only the technology.
- `description` is optional: ONE short line saying what the element does, rendered as a third line. Not a sentence about why it matters, not its threats -- what it is. "Serves chart generation requests", not "critical component handling sensitive requests".
  Both are optional and additive: omit them and the box renders exactly as it did before. Take them from the inventory's Type / Language-Framework and Responsibilities fields, which already hold this.
- `threat` is optional: `"P1"` when a Priority 1 threat in 02-threats.md touches that component, `"P2"` for Priority 2, omitted otherwise. This is the ONLY meaning of a red or orange shape border.
- `secure` is `false` when the flow's Encryption is none/plaintext/unknown OR its AuthN is none/unknown, per its row in 02a-context.md. The script draws those as thick red edges, which is the diagram's at-a-glance answer to "what is unprotected".
- `async` is `true` for broker and event-bus flows; the script dashes them.
- `protocol` is the protocol AND NOTHING ELSE -- `HTTPS`, `HTTP`, `AMQP`, `TLS/5432`, or `?` if genuinely unknown. No DF-NNN, no TB-NNN, no data classification, no auth detail. Long edge labels collide with each other and with the shapes; everything omitted here is still in the 02a-context.md data-flow table, which is where a reader goes for detail.
- `notes` is free text rendered in the diagram's notes box. Put the tier you assigned each component (by ID) here, plus any TB-NNN that backs no flow.

Angle brackets in labels and notes are SAFE and no longer need avoiding. Write `List<String>` and "under 5" or "< 5" as they really are. The renderer double-escapes user text -- html-escaped first so the character displays, then xml-escaped for the attribute -- so a literal `<` renders as a character instead of being treated as markup.
  The old ban existed for the wrong reason. A raw `<` never broke the file; every shape style sets `html=1`, so draw.io treated `<String>` as a tag and silently ATE the rest of the label. Text vanishing is harder to notice than a file that fails to open, which is why the rule was written as "do not generate the characters". With correct escaping the workaround is unnecessary, and contorting a name into `List[String]` misrepresents the code.

### COMPONENT-TO-TIER ASSIGNMENT (your judgment, and the main thing you decide)

Assign EVERY component (data stores DS-NNN and external integrations EXT-NNN are components too) to EXACTLY ONE tier by this FIXED decision table, FIRST MATCH WINS, applied in ID order so two runs assign identically:

1. Human actor / user persona (an actor class from the inventory, not a running service) -- `ACTORS`.
2. External SaaS / external system / third-party integration this system is a client of (type external-saas, or an EXT-NNN record) -- `EXTERNAL`. External systems sit outside all trust zones.
3. Data store (a DS-NNN record, or Type database / cache / object-store / queue / table / secrets-manager) -- `DATA`.
4. Internet-facing edge component -- `EDGE`. Match on POSITION, not just the Type word: a component is EDGE if EITHER (a) its Type/role is gateway / CDN / WAF / load-balancer / reverse-proxy / API-gateway / ingress, OR (b) it is the component that terminates inbound internet traffic -- the first hop from the internet, the destination of the internet-to-edge trust boundary crossing in 02a-context.md, or a component the inventory marks internet-facing. A component receiving external user traffic directly is EDGE even when its Type says `api-service` or `web-app`.
5. Everything else -- internal application services, workers, background jobs, auth modules, lambdas, CI/CD pipelines that do NOT terminate inbound internet traffic -- `APPLICATION`.

Optional `SECURED`: a component the inventory EXPLICITLY marks isolated/secured (an explicit field, not an inference). If you cannot tell, it stays APPLICATION. Do not guess.

Every component matches exactly one rule, so the no-slot defect cannot occur. State each assignment by ID in `notes`.

### TRUST BOUNDARIES ARE STRUCTURAL

A trust boundary TB-NNN is the boundary BETWEEN tiers, shown by an edge leaving one zone container and entering another. It is never a cell and never label text -- edge labels carry the protocol only.

EVERY TB-NNN in the inventory must be RECONCILED: each must correspond to at least one edge whose endpoints sit in different tiers. Because tiers come from your assignment, this is something you check, not the script. If a TB-NNN maps to no such edge, list it in `notes` -- do not drop it.

The property worth checking was never that a string appears on a line; it is that every boundary the inventory claims is actually crossed by something the diagram draws.

### Per-Diagram Specifications

Content selection is MECHANICAL for diagrams 1, 2 and 4 -- a function of the inventory and 02a, not judgment.

**1. `c4-01-context`.** The system as ONE `component` node with id `SYS-001`, every A-NNN from inventory Section 4a as an `actor`, every EXT-NNN as an `external`. Nothing else. If Section 4a is empty the context diagram is wrong, not empty -- go back and derive the actors.

**2. `c4-02-container`.** EVERY C-NNN from inventory Section 2 -- INCLUDING the attested platform components (WAF, ingress, load balancer) carrying `Attested: yes`, which are drawn like any other component so the path from the edge to the application is unbroken, each with the `kind` matching its type, placed in its tier. Edges come from the component Dependencies fields; a dependency with no backing DF-NNN gets `"protocol": ""`. Validation counts nodes against the inventory component count.

**3. `c4-03-component`.** Internal structure of the primary application component -- the ONE judgment-permitted diagram. Its internal elements carry `INT-NNN` ids (see IDS above), never invented C-NNN ids: they are structure inside a component, not components, and an invented C-NNN both misrepresents them and breaks the Validation count. Grounded in what Phase 1 recorded for it: entry points, AuthN/AuthZ and middleware, crypto operations, data-access paths. Anything drawn that the inventory did not record needs a `file:line` citation in `notes`. This diagram is expected to vary between runs; the others are not.

**4. `dfd`.** Gane-Sarson notation, PINNED (never Yourdon): `kind` is `process` for components, `dfdstore` for data stores, `external` for external entities. Every DF-NNN from 02a-context.md becomes an edge; Validation counts them against the 02a total.

### Before rendering: COUNT, do not eyeball

The data file is the one place a whole element can go missing silently, and a missing element cannot be recovered later by looking at the diagram -- you would have to already know it was absent. Count before you render, and state the counts:

- EXT-NNN in inventory Section 4 vs `external` nodes across your diagrams -- these are the ones that go missing most often, because external integrations are recorded in a supplementary section and are easy to skip when walking Section 2.
- C-NNN in inventory Section 2 vs nodes on c4-02 (SYS-/INT- ids excluded).
- DS-NNN in Section 3 vs `store`/`dfdstore` nodes.
- A-NNN in Section 4a vs `actor` nodes on c4-01.
- DF-NNN in 02a-context.md vs edges on the dfd.

Any mismatch is fixed in the DATA FILE before rendering, not after. A count stated and wrong is still better than a count not taken -- but do not proceed on a mismatch you have not explained.

ONE DIAGRAM, ONE PAGE -- owner requirement, 2026-08-04. Each diagram is a single page. Do NOT split a diagram across multiple pages, and do not propose multi-page decomposition with drill-down links as a fix for a crowded or tall diagram: draw.io supports it and it is a natural fit for C4's context/container/component structure, which is exactly why it keeps getting suggested. It is rejected. A reader must be able to see the whole system at once; a diagram that requires clicking through pages to follow a data flow defeats the purpose of drawing it. Crowding is addressed by layout, or by accepting a large page.

### RENDER

Substitute the literal SKILL_DIR, WORKSPACE and PROJECT_NAME from your briefing, and use the invocation form for YOUR shell (common.md rule S -- from bash use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` with the same parameters):

```powershell
& '<SKILL_DIR>\scripts\render-drawio.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
```

Paste its output. It reports, per diagram, the page size, the GRID SHAPE (`grid 6x5` means six columns of cells by five rows), node and edge counts, and the per-gutter load. A gutter carrying more than 8 vertical runs is flagged: that is a diagram which should be SPLIT, because the problem is edge density and no amount of spacing reduces density. Do not try to fix it by editing the output.

### Validation (mandatory, before STATE.md -- a diagram that fails is not written)

```powershell
& '<SKILL_DIR>\scripts\validate-drawio.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
```

Reconcile against the source files and state the result: C-NNN nodes on c4-02 = inventory component count (SYS-NNN and INT-NNN are synthetic and excluded from this count); edges on dfd = the 02a DF count; containers on c4-02 and dfd = the number of component-bearing tiers (NOT the TB count -- trust boundaries are structural, not containers); every TB-NNN reconciled to a tier-crossing edge or listed in `notes`; bad edge refs and bad parents = 0 everywhere. Any TB-NNN that is neither reconciled nor noted is a rule violation -- fix the data file and re-render, never the number.

Return your completion banner to the orchestrator (it owns STATE.md).

**Phase 4 Completion Banner:**
```
=== PHASE 4 COMPLETE: DRAW.IO DIAGRAMS WRITTEN ===
  .\{PROJECT_NAME}-threat-model\diagrams\c4-01-context.drawio
  .\{PROJECT_NAME}-threat-model\diagrams\c4-02-container.drawio
  .\{PROJECT_NAME}-threat-model\diagrams\c4-03-component.drawio
  .\{PROJECT_NAME}-threat-model\diagrams\dfd.drawio
Render output (pasted verbatim):
<paste the render-drawio.ps1 lines -- page sizes, grid shapes, counts, gutter loads>
Validation output (pasted verbatim):
<paste the per-file validation lines -- every file parsed OK, bad refs 0, counts reconciled>
Phase status reported to orchestrator (it owns STATE.md). Threat model run is finished.
```

## Archiving Reminder (returned to the orchestrator)

Return this reminder to the orchestrator so it can print it after the Phase 4 banner:

Phase 3 Disposition Discovery in a FUTURE run searches for archived directories matching `{PROJECT_NAME}-threat-model-*`. Nothing in this workflow creates those archives automatically -- archiving is a deliberate user action taken before starting a new run. After printing the Phase 4 banner, print this reminder verbatim:

```
REMINDER -- before re-running this threat model in the future:
1. Complete stakeholder review and save dispositions.csv into this run's output directory --
   either click 'Export dispositions.csv' in threat-model.html at the end of the review
   session, or use the threat-model-disposition.md prompt.
2. Archive this run by renaming the output directory with a date suffix, e.g.:
   Rename-Item ".\{PROJECT_NAME}-threat-model" ".\{PROJECT_NAME}-threat-model-yyyyMMdd"
3. The next run will then find the archive, read its dispositions.csv, and carry your
   review decisions forward. Without this step, disposition continuity is lost.
```
===== END FILE: references/phase-4.md


---

## Part 3 -- the Phase 4 renderer specification


Build these two scripts from this specification. They are the Phase 4 diagram renderer and its
validator. Write them into `BUILD_ROOT/stride-threat-model/scripts/`.

**Read section 1 before you write a line.** This script exists because prose instructions to
an agent did not work, and you are being handed prose instructions. That is not a contradiction
-- but it does mean the last section, VERIFY BY LOOKING, is not optional politeness. It is the
only thing that separates this from the approach that failed.


## 1. Why this is a script

The agent supplies the DATA -- which element is in which tier, which flows exist, which are
unprotected. That is classification, and an LLM is good at it.

Geometry is arithmetic: roughly fifty coordinates, a dozen four-decimal attachment fractions,
and a channel assignment per edge, for every diagram. An agent computing that by hand on a
25-component system will get some of it wrong, and one wrong coordinate is a visibly broken
diagram. So it belongs in a script, computed the same way every time.

Six defects in the original were found ONLY by rendering a sample and looking at the exported
image. None was visible in the specification text. Most were two individually correct rules
interacting at a case neither anticipated. Section 9 lists all six; they are the highest-value
part of this document, because they are the ones you will otherwise reintroduce.


## 2. Input contract

`render-drawio.ps1` consumes a JSON data file the Phase 4 agent writes. Default location
`{workspace}\{project}-threat-model\04-diagram-data.json`, overridable.

    {
      "diagrams": [
        {
          "name":  "context",              // becomes <name>.drawio, and the mxfile diagram id
          "title": "System Context",       // the diagram page title
          "notes": ["free text", "..."],   // optional; rendered in a NOTES box
          "nodes": [ ... ],
          "edges": [ ... ]
        }
      ]
    }

**Node fields.** `id`, `label`, `kind` and `tier` are required; the rest are optional and each
one changes what is drawn.

| Field | Effect |
|---|---|
| `id` | Unique within the diagram. Referenced by edges. Becomes the mxCell id. |
| `label` | Display name. Rendered bold on the first line. |
| `kind` | One of `component`, `process`, `store`, `dfdstore`, `external`, `actor`. Chooses size and shape style. |
| `tier` | One of `ACTORS`, `EDGE`, `APPLICATION`, `DATA`, `SECURED`, `EXTERNAL`. Chooses the column and the zone box. |
| `tech` | Technology string. Renders as a second line, `[<TypeWord>: <tech>]`. |
| `description` | One-line description. Renders as a third, smaller line. |
| `threat` | `P1` or `P2`. Overrides the shape's border: P1 red `#CC0000`, P2 orange `#E65100`, both `strokeWidth=3`. |

**Edge fields.** `source` and `target` are required node ids.

| Field | Effect |
|---|---|
| `protocol` | The edge's visible LABEL. Note the name: it is `protocol`, not `label`. |
| `async` | Truthy renders the edge dashed. |
| `secure` | **Falsy renders the edge red and thick** -- the "unencrypted or unauthenticated flow" signal. |

**`secure` is tested as `if (-not $e.secure)`, so an ABSENT `secure` field renders the edge as
insecure.** That default is deliberate -- an unmarked flow is not an assurance -- but it means
a data file that omits `secure` everywhere produces a diagram that is entirely red. Say so in
`phase-4.md`: every edge that IS protected must carry `"secure": true` explicitly.

The renderer computes every coordinate itself. **The data file must not contain `x`, `y`, `w`
or `h`.**


## 3. Output contract

One `.drawio` file per diagram, written to `{workspace}\{project}-threat-model\diagrams\<name>.drawio`.

Standard draw.io XML: an `<mxfile>` wrapping one `<diagram id="<name>" name="<title>">`,
containing an `<mxGraphModel>` with a `<root>` holding `<mxCell id="0"/>` and
`<mxCell id="1" parent="0"/>`, then every shape and edge.

- Shapes: `vertex="1"` with `<mxGeometry x y width height as="geometry"/>`, integer coordinates.
- Edges: `edge="1"` with `source` and `target` referencing cell ids, plus
  `<mxGeometry x="-0.4" relative="1" as="geometry">` containing an `<Array as="points">` of
  `<mxPoint>` waypoints. Label in `value`.

Print one line per file written: name, page size, grid dimensions, node count, edge count. Skip
with a printed `SKIP <name>: no nodes` rather than failing, if a diagram has no nodes.


## 4. Geometry constants

    MARGIN   = 40      CELL_W = 400     CELL_H = 240
    VG       = 255     (vertical gutter width)
    HG       = 187     (horizontal gutter height)
    MAX_ROWS = 5       NOTICE_H = 30

Nodes sit in cells of a GLOBAL grid. Between every pair of adjacent grid columns is a vertical
GUTTER, and between every pair of adjacent rows a horizontal one. **Gutters hold no nodes by
construction, and every edge travels only through gutters plus a short stub inside its own
cell -- so no edge can cross a component.**

Position helpers, and they must agree exactly:

    vertical gutter g spans x from  MARGIN + g*(CELL_W+VG)          , width VG
    grid column     c spans x from  MARGIN + c*(CELL_W+VG) + VG     , width CELL_W
    horizontal gutter h spans y from MARGIN + h*(CELL_H+HG)         , height HG
    grid row        r spans y from  MARGIN + r*(CELL_H+HG) + HG     , height CELL_H

Sizes by kind (width, height):

    component 400x200    process 400x200    external 400x200
    store     320x240    dfdstore 320x240   actor    120x200

Column order, left to right: `ACTORS, EDGE, APPLICATION, DATA, SECURED, EXTERNAL`.
Tiers drawn inside a dashed zone box: `EDGE, APPLICATION, DATA, SECURED` (not ACTORS, not
EXTERNAL).

Zone colours: EDGE `#E65100`, APPLICATION `#B58C00`, DATA `#00695C`, SECURED `#2E7D32`.

Style strings, used verbatim -- these are draw.io configuration values, and guessing them
changes the look for no benefit:

    component/process  rounded=1;whiteSpace=wrap;html=1;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=20;
    store              shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=15;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=20;
    dfdstore           shape=partialRectangle;whiteSpace=wrap;html=1;left=0;right=0;top=1;bottom=1;fillColor=#DAE8FC;strokeColor=#2E6295;fontSize=20;
    external           rounded=0;whiteSpace=wrap;html=1;fillColor=#999999;strokeColor=#666666;fontColor=#FFFFFF;fontSize=20;
    actor              shape=umlActor;verticalLabelPosition=bottom;verticalAlign=top;html=1;strokeColor=#666666;fontSize=20;
    zone (prefix)      rounded=1;container=1;collapsible=0;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=22;fontStyle=1;fillColor=none;dashed=1;strokeWidth=2;strokeColor=
    edge               edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=16;endArrow=classic;labelBackgroundColor=#FFFFFF;jettySize=30;jumpStyle=arc;jumpSize=10;
    legend/notes       rounded=0;whiteSpace=wrap;html=1;fillColor=#F5F5F5;strokeColor=#666666;fontSize=16;align=left;verticalAlign=top;
    notice             text;html=1;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;fontSize=16;fontStyle=2;


## 5. Labels

The C4 convention: name in bold, then element type and technology, then a one-line description.

    <b>{label}</b>
    <div style="font-size:15px">[{TypeWord}: {tech}]</div>     if tech
    <div style="font-size:15px">[{TypeWord}]</div>             if no tech
    <div style="font-size:14px">{description}</div>            if description

TypeWord by kind: component -> `Container`, process -> `Process`, store and dfdstore ->
`Data Store`, external -> `External System`, actor -> `Person`.

**DOUBLE ESCAPING IS THE POINT.** User text is HTML-escaped FIRST (`&`, `<`, `>`) so a literal
`<` in a component name displays as a character; the markup above is added around it; then the
whole string is XML-escaped for the attribute (`&`, `<`, `>`, `"`). Single-escaping leaves a
raw `<` in the decoded value, and `html=1` then treats it as a tag and **silently eats the rest
of the name**. The text does not break the file -- it disappears, which is far harder to notice.


## 6. Layout, in five stages

### Stage 1 -- which tiers are present

Keep only tiers with at least one member, in column order. Assign each a column index.

**Guard the single-member case.** In PowerShell 5.1 a `Where-Object` matching exactly one
object returns that object, not an array, and a PSCustomObject has no `.Count` -- so a tier
with a single member silently tested as empty and the whole column vanished from the layout.
Wrap such pipelines in `@()`.

### Stage 2 -- barycentre ordering within tiers

Decide WHICH member sits in WHICH slot before computing any coordinate. Members arrive in
inventory-id order, which is arbitrary with respect to what connects to what.

Each node is pulled toward the average normalised position of everything it connects to.
Normalised position is `index / (count - 1)` within its own tier, or `0.5` for a tier of one.
Sweep the columns forward, then backward, then forward, then backward -- four sweeps -- because
reordering one column changes the right answer for its neighbours. Skip tiers with fewer than
three members. Sort each tier by score, breaking ties on id so the result is deterministic.

**SAME-COLUMN EDGES COUNT TOO.** They are exactly the edges that produce long in-tier runs, so
leaving them out of the neighbour set means the ordering cannot fix what it exists for.

### Stage 3 -- grid assignment, with wrapping

Each tier claims a contiguous RANGE of global grid columns. A tier with more than `MAX_ROWS`
members WRAPS into more than one column: `cols = ceil(n / MAX_ROWS)`, `rows = ceil(n / cols)`.

This is the point of the whole model: nine components in a single file down the page is not a
shape anyone would draw by hand, and it forced every other tier to stretch to match.

Fill **column-major** -- sub-column `floor(s / rows)`, row `s % rows`. Row-major would scatter
neighbours across the grid and undo stage 2.

**Centre short tiers vertically** rather than pinning them to row 0: offset by
`floor((totalRows - tierRows) / 2)`. A one-member edge tier at row 0, while the application
tier runs five rows deep, leaves its edges climbing the full height of the page.

### Stage 4 -- cell refinement

Which SUB-COLUMN a member lands in was decided by its place in a vertical ordering, which has
nothing to do with what it connects to. On a real repository that put two components called
directly by the edge tier two sub-columns away from it. Wrapping a tier shortens the column but
LENGTHENS the edges unless placement is told to care, and those manufactured long edges are
most of the crossings.

So: swap members within their own tier while it reduces total edge span. Cost function:

    for each edge:  3.0 * |Δcolumn|  +  1.0 * |Δrow|
                    +9.0 once, if any cell between the two columns, AT THE TARGET'S ROW,
                     is occupied

Horizontal span is weighted heavier because a long horizontal run crosses every vertical run it
passes. A BLOCKED route is priced separately because it is not merely longer -- it is a
different shape, leaving its row entirely to run in a shared gutter.

Six passes maximum, strict improvement only, stop early when a pass improves nothing. Fixed
pass count and strict improvement keep it deterministic.

### Stage 5 -- absolute geometry

Centre each node in its cell: `x = ColX(c) + (CELL_W - w)/2`, `y = RowY(r) + (CELL_H - h)/2`.


## 7. Edge routing

### Exit and entry fans

Order each node's edges by the other end's centre y, so parallel runs do not cross in front of
the shape they leave. The attachment fraction for the i-th of n edges:

    0.10 + 0.80 * ((i + 0.5 + 0.4 * phase) / n)      rounded to 4 decimals

**The `phase` term is not decoration.** Every node in a grid row spans the same band of y, so a
plain `(i+1)/(n+1)` fan puts node A's second exit at exactly the height of node B's second
entry -- and those two horizontal stubs then overlay inside the shared gutter and draw as ONE
line. `phase` is the node's index among its row's members sorted by x, divided by the row's
member count. It shifts each node's fan by a fraction of a lane, separating them without a
global lane allocation that would be far too tight to see.

### Route plan

- Target to the RIGHT: leave by the source's right into vertical gutter `sourceCol + 1`, arrive
  at the target's left out of vertical gutter `targetCol`.
- Target to the LEFT: mirror it -- exit left from gutter `sourceCol`, enter right at
  `targetCol + 1`.
- SAME column: exit right and enter right, both via gutter `sourceCol + 1`.

When the two gutters are the same, the route is one vertical run and needs no horizontal gutter.

**Detour only when the way is actually BLOCKED.** The final horizontal approach runs at the
TARGET's height across the columns between the two nodes, so it is the TARGET's row that must
be clear -- not the source's. An unconditional detour sent edges over the top of the page that
had a clear run straight in.

When blocked, choose the **nearest usable horizontal gutter, not always the one above the
target.** "Above the target" is the outer top margin for anything in row 0, which put most of
the long traffic in one lane across the whole page. Cost each candidate gutter `h` in
`0..totalRows`:

    |gutterCentreY - exitY| + |gutterCentreY - entryY| + 140 * (edges already using h)

The congestion term is what stops a popular lane from remaining the cheapest.

**Plan edges in a fixed order** -- sort by `"source|target"`. The gutter choice is greedy and
congestion-aware, so without a fixed order the same input renders differently each run.

### Channel allocation

Two runs in the same gutter must not share an x (or a y). Collect every user of each gutter,
sort them geometrically so neighbours stay neighbours -- vertical gutters by the sum of the two
endpoints' centre y, horizontal by the sum of centre x, ties on the edge key -- then spread
evenly: the i-th of n gets `gutterStart + (i+1) * gutterSize / (n+1)`.

### Waypoints

    no horizontal gutter:   (x1,y1)  and, if y1 != y2, (x1,y2)
    with horizontal gutter: (x1,y1), (x1,yh), (x2,yh), (x2,y2)

Attachment on the cell: `exitX=1` or `0` with `exitY=<fraction>`, plus
`exitDx=0;exitDy=0;exitPerimeter=0;` and the matching `entry*` set.

**Build the waypoint list in a real list type, not a nested array literal.** PowerShell unwraps
a one-element array of arrays, so the single-waypoint case collapsed into two scalars and
emitted `<mxPoint x="890" y=""/>`.

### Edge label position

`<mxGeometry x="-0.4" relative="1">` -- biased toward the source end (-1 is source, 1 is
target). At the DEFAULT midpoint a label lands on whatever the line happens to cross: rendering
a real repository put `in-process` on top of a component's own title and `HTTPS` on a database
cylinder. Biasing toward the source keeps it in the gutter just outside the shape.


## 8. Zones, legend, notice, page

**Zones.** For each contained tier, bound its members and pad: left and right 60, TOP 90,
bottom 60. The larger top pad leaves room for the zone's own title. Emit the zone first, then
its members as children with `parent="zone-<TIER>"` and coordinates RELATIVE to the zone.
Non-contained tiers (ACTORS, EXTERNAL) emit with `parent="1"` and absolute coordinates.

**Legend**, 480x360 at x=40. Content: the word LEGEND, then one line per present zone tier,
then `Red thick edge = unencrypted or unauthenticated flow` and the threat-border meanings.

Placement is conditional, and this is the fiddly part. Centring short tiers vertically is worth
roughly 23 crossings down to 9, but it opens a large void at the TOP LEFT. Parking the legend
below all content left that void empty AND stretched the page. So: try `y = NOTICE_H + 40`, and
**check it against the actual node rectangles** -- if any node with `x < 1100` overlaps the band
the legend would occupy, fall back to `bottom + 160`. A diagram whose first tier IS tall has no
void, and a legend pinned to the top would land on a component.

**Notes box**, same size and y, at x=560, when the diagram has `notes`. Join the note lines
with `&#10;`.

**AI notice**, inserted as the FIRST cell so it sits behind nothing: at x=40, y=0, height
`NOTICE_H`, spanning the page width, reading:

    AI-GENERATED -- this diagram was produced by an AI tool and requires human review.

This is required on every diagram; it is Operating Rule 16.

**Page size.** Round up to a 40-pixel grid, minimum height 1600, and take the greater of the
content bottom and the legend bottom, plus 80.


## 9. The six defects -- check for every one of these

These were found by rendering and looking. Each was invisible in the specification text. After
you build the script, verify each explicitly against a rendered diagram.

1. **A single-member tier disappears.** The `@()` coercion in stage 1. Symptom: an entire
   column missing from the layout.
2. **Barycentre ignores same-column edges.** Symptom: long vertical runs inside one tier that
   reordering should have fixed.
3. **Wrapped tiers manufacture long edges.** Stage 4 exists for this. Symptom: components that
   talk to each other placed sub-columns apart.
4. **Two edges draw as one line.** The missing `phase` term. Symptom: a gutter that looks like
   it carries one flow but carries two.
5. **Case-insensitive variable collision.** In the original, the per-edge horizontal-gutter
   index was nearly named `$hg`, which in PowerShell IS the `$HG` gutter-height constant --
   assigning a row index to it silently set `HG` to 1, collapsing every horizontal channel into
   a 1px band that read as four edges sharing a single line. **Name it `$hgIdx` or anything
   else.** PowerShell variable names are case-insensitive; this class of bug is invisible in
   review.
6. **Unconditional detours.** Edges routed over the top of the page that had a clear straight
   run. Fixed by testing the TARGET's row for occupancy.

Plus the two escaping traps: single-escaped labels silently eat text (section 5), and the
unwrapped single waypoint emits `y=""` (section 7).


## 10. validate-drawio.ps1

Small, and its job is narrow: prove each emitted file is well-formed and internally consistent.

For each `.drawio` in the diagrams directory:

1. Parse it as XML. A parse failure prints `PARSE FAIL <file>` and is a hard failure.
2. Collect every `mxCell` id.
3. For every edge cell, check that its `source` and `target` both exist in that id set. Count
   the ones that do not.
4. Print one line per file: name, `PARSE OK` or `PARSE FAIL`, cell count, edge count, and bad
   reference count.

Exit 1 if any file fails to parse or has any bad reference. A failing diagram is not done.


## 11. VERIFY BY LOOKING -- do not skip this

Everything above is prose describing a thing that exists because prose did not work. The
difference between this attempt and that one is this section.

1. Write a small data file by hand: two tiers, four or five nodes across them, at least one
   `store`, one `actor`, one edge with `secure: true`, one without, one with `async: true`, and
   one node with `threat: "P1"`.
2. Render it. Run the validator. Both must pass.
3. **Open the `.drawio` file and look at it.** In draw.io, or by exporting an image.
4. Check, by eye, in this order:
   - Every node appears. Count them against the data file. (Defect 1.)
   - No edge crosses over a component box. Edges belong in gutters.
   - No two edges are drawn on top of each other. (Defect 4.)
   - Edge labels sit in open space, not on top of a shape.
   - The insecure edge is red and thick; the async edge is dashed; the P1 node has a red border.
   - Labels are complete -- no name truncated at a `<` character. (Section 5.)
   - The legend does not overlap any component.
   - No waypoint reads `y=""` in the XML. (Section 7.)
5. Then scale up: render the real Phase 4 data for an actual system and look again. Layout
   defects appear at 20 components that are invisible at 5.

If something looks wrong, fix the script and re-render. **Do not adjust the data to work around
a layout bug** -- the data is the agent's classification and it is correct; the geometry is
yours and it is not.

Report what you checked and what you saw. "It rendered without error" is not an answer to any
of the questions in step 4.


---

## Part 4 -- manifest

After Step 1, each file must match this exactly. Report the ACTUALS, not a claim that they
match. A file that is short is the likely failure and nothing else will report it.

### references/phase-0.md

    lines       156
    bytes       28089
    first line  <!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT V
    last line   After the user approves the Scope Proposal, run `& '<SKILL_DIR>\scripts\partition-manife

### references/phase-0-discovery.md

    lines       143
    bytes       25025
    first line  <!-- SKILL VERSION: v25-skill (2026-07-24g) -- methodology carved verbatim from PROMPT V
    last line   ## Completeness self-audit (mandatory, before you return) For each element category -- s

### references/phase-4.md

    lines       171
    bytes       16893
    first line  <!-- SKILL VERSION: v26-skill (2026-08-04a) -->
    last line   ```

A note on bytes: if your editor writes CRLF line endings the byte count will be higher by
roughly the line count. That is fine. The LINE count must match exactly.

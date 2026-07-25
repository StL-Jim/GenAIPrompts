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

   Q6a (ask only when Q6 = PLATFORM-INHERITED): "Describe the platform's standard traffic path for this application and where TLS terminates (e.g., 'Akamai WAF -> reverse proxy -> app container; TLS terminates at the proxy; plaintext HTTP from proxy to container'). Include anything else the platform imposes that affects this app's security posture (network segmentation, service-mesh mTLS, egress restrictions) -- or answer 'unknown'."
   The answer is the ATTESTED PLATFORM PROFILE: user-supplied facts treated as citable evidence per Operating Rule 2, cited as `[evidence: user-attested, Phase 0 Q6a]`. Together with Q3's existing controls it has two faces, and the model MUST use both -- but they carry ASYMMETRIC force (Operating Rule 2): attested EXPOSURES (e.g., the plaintext hop after TLS termination) carry full evidentiary force and ground threats in the main table even in PLATFORM-INHERITED mode; attested CONTROLS (e.g., the WAF absorbs volumetric DDoS) feed SecurityControl (as `Attested -- ... (unverified in code)`) and ResidualRisk credit, but never solely justify a fully-mitigated exclusion -- a candidate suppressed only by an attested control is recorded as `Attested-mitigated (unverified)` in the Excluded Threats Ledger, where the code audit picks it up as a verification lead. Attestation is evidence, not speculation. If the user answers 'unknown', record that in the Assumptions Log and proceed without a topology profile.

   Record all answers in STATE.md under a ## User Inputs section and include them in 00-scope.md. (The exposure answer is validated against discovery evidence in step 7.6, after the sweep has run -- not here, where nothing has been read yet.)

7. **EXHAUSTIVE DISCOVERY -- dispatch the discovery subagent.** This is the highest-leverage step in the workflow, and it is the one step of Phase 0 that does NOT run in your session: deep reading needs a full, dedicated context window, and running it here would make it compete with orchestration and user dialogue (a model managing a conversation economizes on reading -- a field-observed failure). Dispatch ONE general-purpose subagent per SKILL.md's dispatch table, briefed on `references/phase-0-discovery.md`. It runs Pass 1 (source investigation), Pass 2 (mechanical sweep), the refinement, and the completeness self-audit, and it writes `00-discovery.md`, `00-discovery-raw.txt`, `00-density.txt`, and `00-candidates.txt`.

   When it returns, verify before continuing: `00-discovery.md` exists and is non-trivial; its Pass 1 reading accounting shows docs-read equal to docs-in-manifest; and its depth verdict is not THIN. If the agent reports THIN, or its reading accounting shows it read only a handful of files, RE-DISPATCH it with the shortfall named -- do not proceed to scope on a shallow discovery, because nothing downstream will catch what it missed. Paste its returned discovery summary.

7.6. **Exposure validation (mandatory, after the sweep, before writing 00-scope.md).** Validate the user's Q1 exposure answer against what the sweep and repo map actually surfaced: ingress/edge references (public hostnames, LB/WAF/CDN references, `0.0.0.0` binds, Ingress resources or internet-facing IaC if present in this repo). This is a consistency check on attested facts, not a re-derivation. Record a one-line verdict for 00-scope.md: `Exposure validation: Q1=<answer>; discovery evidence <consistent | CONFLICT: <what the evidence shows>>`. A CONFLICT verdict MUST be surfaced in the step 9 Scope Proposal for the user to adjudicate (the user may know infrastructure this repo cannot show); record their ruling in 00-scope.md. Under PLATFORM-INHERITED infra, thin edge evidence in the repo is normal and is NOT a conflict -- flag a conflict only when found evidence positively contradicts the answer.

7.7. **Write 00-resources.txt (ALWAYS), then archive comparison (completeness cross-check, only when a prior archive exists).** This step has two parts. Part 1 is UNCONDITIONAL and runs on every assessment, including a first run with no prior archive; only Part 2 (the comparison) is gated on a prior archive existing. Do not skip Part 1 just because this is a first run.

   Part 1 (always): write `{PROJECT_NAME}-threat-model/00-resources.txt`: this run's own final DISTINCT resource list in machine-readable form, one per line, two tab-separated columns: `type<TAB>canonical name`, where type is one of `bucket|table|database|queue|topic|cache|agent|external-api|identity-provider|secret-store|service|other`. CANONICAL NAME FORMAT (pin this exactly, or cross-run comparison produces false diffs): the canonical name is the BARE resource identifier as it literally appears in the code or IaC -- the actual bucket name, table name, queue name, hostname, or service id -- lowercased, with NO type word or prefix (write `filings-documents`, never `s3 filings-documents` or `bucket:filings-documents`; the type lives in its own column), NO surrounding quotes, and NO environment decoration added or stripped beyond what the identifier literally contains. One line per distinct resource. Sort the file. This exact-string discipline is what lets a later run's `Compare-Object` detect real drift instead of formatting noise. Its line count MUST equal the distinct-list count in 00-discovery.md (state both, per Operating Rule 15). It is written here, before the comparison below, so this step (and every future run's comparison) has this run's own list on disk -- step 8 below no longer writes it (see the note in step 8).

   Part 2 (only when a prior archived run exists): compare this run's 00-resources.txt against the most recent archive, as follows.

   Run the comparison script (one call; use YOUR shell's invocation form per common.md rule S):
   ```powershell
   & '<SKILL_DIR>\scriptsrchive-compare.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
   ```
   It finds the most recent archived run, picks the comparison basis (the archive's `00-resources.txt`, or its `01-inventory.md` element names as a weaker name-only fallback, or reports that it cannot be compared), and prints the FOUR sets described below plus both resource counts. If no archive exists it says so and you skip to step 8 without writing 00-archive-comparison.md. Paste its output.

   Write the result to `{PROJECT_NAME}-threat-model/00-archive-comparison.md` with the Write tool (common.md rule W): which archived run was compared (name, LastWriteTime), the comparison basis (00-resources.txt name column, the 01-inventory.md fallback, or "could not be compared" with the reason), and the FOUR named sets in full, not just counts -- (1) in prior/not in current (DISCOVERY drift / possible regression), (2) in current/not in prior (new), (3) same name/different type (CLASSIFICATION drift -- the same resource re-binned, e.g. a fetched-from source corrected from data-store to external-api; NOT a missed resource), and (4) unchanged. This is a completeness cross-check, not an auto-merge: never silently pull a prior run's resource into this run's scope on the strength of this comparison -- every "in prior, not in current" item is surfaced as a question for the user, never merged in automatically.

   The "in prior, not in current" set is a possible completeness REGRESSION (something the prior run found that this run missed) or a legitimately removed/decommissioned resource -- either way it MUST be investigated or explained before scope closes, so it is REQUIRED to also appear in the step 9 Scope Proposal as an explicit question for the user to adjudicate at GATE 1: the user may know a resource was decommissioned, or may recognize a real miss that sends discovery back for another look. Record the user's ruling on each item in 00-scope.md.

8. **Write a scoping note** to `{PROJECT_NAME}-threat-model/00-scope.md`. PRECONDITION (do not write this file until all of it holds): steps 7 (both passes + refinement), 7.5, 7.6, and 7.7-Part-1 have completed and their artifacts exist on disk -- `00-discovery.md`, `00-discovery-raw.txt`, `00-candidates.txt`, `00-density.txt`, and `00-resources.txt`. 00-scope.md is a synthesis OF those artifacts; writing it before they exist produces a scope guessed from memory, not derived from discovery (a field-observed failure). If any artifact is missing -- e.g. the sweep did not finish -- STOP and complete discovery first; do not write a partial scope. The note captures `PROJECT_NAME`, `WORKSPACE`, the detected repo type (and which classification rule fired), languages/frameworks with evidence, deployment exposure (from step 6) with the step 7.6 exposure-validation verdict line, the data stores and external integrations -- every distinct item from 00-discovery.md triaged as in-scope or out-of-scope-with-reason (nothing from the sweep silently absent), split into IaC-defined (schema/config in this repo's infrastructure files) and runtime-referenced (named in application code but not in this repo's IaC; cite the referencing source file) so the code-vs-IaC provenance is visible, the infrastructure ownership mode (Q6: SELF-MANAGED or PLATFORM-INHERITED -- and when PLATFORM-INHERITED, state explicitly that the platform's internal configuration is inherited and assessed elsewhere, reproduce the Q6a attested platform profile verbatim so later phases can cite it, and note that the app's side of every data flow plus attested exposures remain in scope), in-scope components, and explicit out-of-scope items (e.g., vendored third-party code under `node_modules/`, `vendor/`, `target/`, `.venv/`; tool-state directories such as `audit_state/` from the CodeSecurityAudit prompt and `{PROJECT_NAME}-threat-model/` from this prompt's own prior runs). Every item in this list is MANDATORY: a scope note missing any of them is a rule violation, not a style choice. Classify each data store vs external integration by the DS-vs-EXT ownership test (Phase 1 output schema, Section 3) -- the operator question: content this system owns = data store even on managed infrastructure; service another party operates with this system as client = external integration even if this system only fetches data from it (a scraped/fetched-from remote source is an EXT, never a data store -- the fetch trap; the place fetched data lands is a separate DS). Achieve brevity through terseness per item, never by omitting an item -- Operating Rule 9's token budget governs reading, not this file's completeness. Write the file with the Write tool (common.md rule W).

   `{PROJECT_NAME}-threat-model/00-resources.txt` was already written in step 7.7, before the archive comparison that step performs against it. This is the cross-run comparison artifact: any later run (or a second pass of this one) is unioned against it with `Compare-Object (Get-Content run1) (Get-Content run2)` -- so both discovery drift AND classification drift between runs become visible mechanically. Confirm here that its line count still equals the distinct-list count in 00-discovery.md (state both, per Operating Rule 15); do not rewrite it unless that count is wrong.

9. **Print a Scope Proposal** containing the same information from step 8 plus any ambiguity that requires a user decision (multi-service monorepo -- which service? unclear scope boundaries?), any step 7.6 exposure-validation CONFLICT stated explicitly as a question for the user to adjudicate, and -- when step 7.7 found a prior archive -- its "in prior, not in current" set stated explicitly as a question for the user to adjudicate (regression or legitimate removal). This is the proposal the user reviews before Phase 1 begins.

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
Pass 1 depth check: <adequate | THIN -- investigation was shallow, see Scope Proposal>
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

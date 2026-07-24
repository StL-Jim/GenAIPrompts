<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

# Phase 0 -- Initialization and Scoping (ORCHESTRATOR-RUN)

**Goal:** Derive inputs, validate the workspace, set up the output directory, prevent it from being committed to the source repo, initialize STATE.md, and produce a scope proposal for user review.

**Steps:**

1. **Derive inputs and validate the workspace.** Run this PowerShell block in the terminal and print the output so the user can confirm:
   ```powershell
   $WORKSPACE    = (Get-Location).Path
   $PROJECT_NAME = Split-Path -Leaf $WORKSPACE
   $OUTPUT_ROOT  = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"
   $CURRENT_DATE = Get-Date -Format "yyyy-MM-ddTHH:mm"

   if (-not (Test-Path (Join-Path $WORKSPACE '.git'))) {
       Write-Warning "Workspace is not a git repo (no .git directory found). Continuing anyway."
   }

   "WORKSPACE    = $WORKSPACE"
   "PROJECT_NAME = $PROJECT_NAME"
   "OUTPUT_ROOT  = $OUTPUT_ROOT"
   "CURRENT_DATE = $CURRENT_DATE"

   $archivedRuns = Get-ChildItem -Path $WORKSPACE -Directory -Filter "$PROJECT_NAME-threat-model-*" -ErrorAction SilentlyContinue
   if ($archivedRuns) {
       "prior archived runs (read-only reference): " + ($archivedRuns.Name -join ', ')
   } else {
       "prior archived runs (read-only reference): none"
   }
   ```

   ASSERTION: OUTPUT_ROOT is ALWAYS the canonical, unsuffixed name `{PROJECT_NAME}-threat-model` -- computed only from $WORKSPACE and $PROJECT_NAME as shown above, never from anything printed by the archived-runs listing. Any sibling directory matching `{PROJECT_NAME}-threat-model-<suffix>` (a date suffix, e.g. `{PROJECT_NAME}-threat-model-20260601`) is a PRIOR ARCHIVED RUN, created by the end-of-Phase-4 archiving step (see the Archiving Reminder in phase-4.md), not the current run. This run must never write into an archived directory and must never treat one as the current OUTPUT_ROOT -- the block above lists any that exist purely so the orchestrator can see them (and so step 7.7 below can compare against the most recent one); it does not target them. SKILL.md's Session Start applies the same rule to resuming: an archived `-yyyyMMdd` directory is never a resume target even if it still holds its own STATE.md from when it was the active run.

   This is the ONLY block in this phase that derives WORKSPACE from `(Get-Location).Path`. Note the printed WORKSPACE and PROJECT_NAME values (and the SKILL_DIR path given in SKILL.md) as literal strings now -- every later block in this phase substitutes them as literals instead of re-deriving them.

   Shell state does not persist between tool calls: each PowerShell block runs in a fresh shell, so WORKSPACE, PROJECT_NAME, OUTPUT_ROOT, and SKILL_DIR must be re-declared at the top of EVERY later PowerShell block in this phase, using the literal values just printed (CURRENT_DATE is not part of this prelude -- re-run Get-Date where needed instead). Never re-derive WORKSPACE from `(Get-Location)` in a later block -- the working directory does not reliably persist between tool calls, and a wrong value silently writes this run's artifacts into a different repository. The re-declaration prelude is:
   ```powershell
   $WORKSPACE    = '<the literal WORKSPACE path printed in step 1>'
   $PROJECT_NAME = '<the literal PROJECT_NAME printed in step 1>'
   $OUTPUT_ROOT  = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"
   $SKILL_DIR    = '<the literal SKILL_DIR path given in SKILL.md>'
   ```
   Substitute all three literal paths -- WORKSPACE and PROJECT_NAME from step 1's printed output, SKILL_DIR from SKILL.md (the directory containing it).

   If `PROJECT_NAME` does not match what the user expects (e.g., they opened a parent folder by accident), STOP and ask them to re-open the correct workspace before continuing.

2. **Create the output directory tree** inside the workspace:
   ```powershell
   $WORKSPACE    = '<the literal WORKSPACE path printed in step 1>'
   $PROJECT_NAME = '<the literal PROJECT_NAME printed in step 1>'
   $OUTPUT_ROOT  = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"
   $SKILL_DIR    = '<the literal SKILL_DIR path given in SKILL.md>'

   if (-not (Test-Path (Join-Path $WORKSPACE '.git'))) {
       throw "WORKSPACE '$WORKSPACE' has no .git -- this looks like a mistargeted path (wrong repo), not the intentional non-git-repo case step 1 already warned about. Re-check the literal WORKSPACE value from step 1 before continuing."
   }

   New-Item -ItemType Directory -Path $OUTPUT_ROOT -Force | Out-Null
   New-Item -ItemType Directory -Path (Join-Path $OUTPUT_ROOT 'diagrams') -Force | Out-Null
   New-Item -ItemType Directory -Path (Join-Path $OUTPUT_ROOT 'outputs')  -Force | Out-Null
   Get-ChildItem -Path $OUTPUT_ROOT -Directory | Select-Object Name
   ```

3. **Exclude the output directory from the source repo's git tracking** using the repo-local, un-committed exclude file. This keeps the threat model artifacts from accidentally appearing in a commit, diff, or PR against the source repo, without modifying any file that would itself need to be committed (important at a regulated org where modifying `.gitignore` may require code review). The pattern is a WILDCARD, not an exact name, because the Archiving instructions (end of Phase 4) rename this directory with a date suffix (`{PROJECT_NAME}-threat-model-yyyyMMdd`) for reuse across runs -- an exact-name entry would stop covering the directory the moment it is archived, silently exposing it to `git status` and a future accidental `git add`:
   ```powershell
   $WORKSPACE    = '<the literal WORKSPACE path printed in step 1>'
   $PROJECT_NAME = '<the literal PROJECT_NAME printed in step 1>'
   $OUTPUT_ROOT  = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"
   $SKILL_DIR    = '<the literal SKILL_DIR path given in SKILL.md>'

   $excludeFile = Join-Path $WORKSPACE '.git\info\exclude'
   if (Test-Path $excludeFile) {
       $entry = "$PROJECT_NAME-threat-model*/"
       $current = Get-Content $excludeFile -Raw -ErrorAction SilentlyContinue
       if ($current -notmatch [regex]::Escape($entry)) {
           Add-Content -Path $excludeFile -Value "`n# Added by STRIDE threat modeling agent`n$entry" -Encoding UTF8
           "Added '$entry' to .git/info/exclude"
       } else {
           "'$entry' already present in .git/info/exclude"
       }
   } else {
       Write-Warning "No .git/info/exclude found; skipping exclude setup. You may see the output directory in 'git status'."
   }
   git -C $WORKSPACE status --short -- "$PROJECT_NAME-threat-model*/" 2>&1
   ```
   If the `git status` output shows files in the output directory (current OR any archived `-yyyyMMdd` copy), the exclude did not take effect and you should warn the user before proceeding.

4. **Initialize STATE.md** with the Write tool: all phases pending per the STATE.md schema in SKILL.md, LAST_UPDATED set to the current ISO 8601 timestamp, Resume Instruction = "Begin at Phase 0."

5. **Produce a top-level repo map** using PowerShell for a full listing:
   ```powershell
   $WORKSPACE    = '<the literal WORKSPACE path printed in step 1>'
   $PROJECT_NAME = '<the literal PROJECT_NAME printed in step 1>'
   $OUTPUT_ROOT  = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"
   $SKILL_DIR    = '<the literal SKILL_DIR path given in SKILL.md>'

   Get-ChildItem -Path $WORKSPACE -Force |
     Where-Object { $_.Name -ne "$PROJECT_NAME-threat-model" -and $_.Name -ne '.git' } |
     Select-Object Mode, Name
   ```
   Classify the repo as one of: `single-service`, `monorepo-multi-service`, `library`, `infrastructure-only`, `mixed`. Apply this decision table IN ORDER, first match wins -- do not classify by feel:
   1. Two or more independently deployable services (separate build/deploy manifests -- e.g. sibling service dirs each with their own Dockerfile / package.json / go.mod / pom.xml) -> `monorepo-multi-service`
   2. No application entry point at all -- only IaC (`*.tf`, k8s manifests, pipelines) -> `infrastructure-only`
   3. A build file that publishes a package/artifact for other code to import, and no runnable service entry point -> `library`
   4. Exactly one deployable application (one entry point / one deploy manifest) -> `single-service`
   5. Anything else (runnable app + substantial IaC for OTHER systems, app + published library, etc.) -> `mixed`
   Record the classification and which rule fired in 00-scope.md.

5a. **Produce a COMPLETE recursive file manifest** -- this is the ground truth Phase 1 must account for, and it is what makes a single run's coverage self-evident instead of only knowable by comparing against a prior run. Enumerate every file (paths only -- no reading, so this is cheap even on large repos), excluding the tool-state and vendored directories that never generate threats:
   Run the extracted script and paste its output:
   ```powershell
   $WORKSPACE    = '<the literal WORKSPACE path printed in step 1>'
   $PROJECT_NAME = '<the literal PROJECT_NAME printed in step 1>'
   $OUTPUT_ROOT  = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"
   $SKILL_DIR    = '<the literal SKILL_DIR path given in SKILL.md>'

   & $SKILL_DIR\scripts\manifest.ps1 -Workspace $WORKSPACE -ProjectName $PROJECT_NAME
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

7. **Identify primary language(s), framework(s), build system(s), and the concrete elements in scope** -- only from files you have directly observed. Look for `package.json`, `pom.xml`, `*.csproj`, `go.mod`, `requirements.txt`, `Cargo.toml`, `*.tf`, `Dockerfile`, `*.yaml` (k8s/helm), etc. Use the Read tool for each detection file and cite with evidence paths relative to the workspace root. "Identify" here means ENUMERATE BY CONCRETE IDENTITY, not "name the stack": list each service/process, each data store, each external integration, each secret location, and each pipeline/workflow you can see at scope level, by its actual name/id -- not a count. A generic quantifier standing in for a list ("several agents", "various services", "multiple buckets", "etc.") is a rule violation, not shorthand: if you are about to write "several X", stop and enumerate every X (use `Select-String` for the pattern to find them all, then read the relevant ranges). This is generic to any stack -- the element TYPES are fixed, the instances are whatever this repo actually contains.

   EXHAUSTIVE DISCOVERY -- run BEFORE scope so nothing is excluded by never being found. The highest-miss category is RUNTIME-REFERENCED resources (data stores, buckets/tables, queues, agents, external APIs, secrets the application CODE or DOCS reference but that are NOT in this repo's IaC -- common under PLATFORM-INHERITED infra). Discovery is TWO INDEPENDENT PASSES plus a REFINEMENT -- belt and suspenders by design. The passes use DIFFERENT mechanisms with different blind spots: comprehension (Pass 1) understands everything it reads but cannot read everything; the mechanical sweep (Pass 2) touches everything but understands nothing. Run them independently -- do not let one steer the other -- and merge them in the refinement, where each catches what the other missed.

   PASS 1 -- SOURCE INVESTIGATION (the primary method; most of this phase's effort goes here). Scope your reading to files in 00-file-manifest.txt: the manifest already excludes this workflow's own output (`{PROJECT_NAME}-threat-model*`, including archived `-yyyyMMdd` copies), the Code Security Audit prompt's state directory (`audit_state*`), its root findings log (`security_architecture_audit.md`), and vendored/generated directories -- so do NOT read, glob into, or cite any of those (Operating Rule 13a). A prior threat model's or audit's output is not documentation about this system; treat the manifest as the boundary of what exists to investigate. Read the source like the security architect you are. Start from the entry points and main modules, follow their imports and references outward, and read deeply -- Operating Rule 9 ranges for files over ~2000 lines, full reads otherwise. Extract every element BY CONCRETE IDENTITY as you go: every service/process, data store, bucket, table, queue, agent, external endpoint, integration, and secret surface the code defines or references -- including ones no pattern could catch (dynamically-constructed names, resources described only in comments). Also read EVERY documentation file at ANY depth, IN FULL (`README*`, `*.md`, `ARCHITECTURE*`, `DESIGN*`, `SECURITY*`, `THREAT*`, anything under `docs/`, `doc/`) -- a prose sentence like "integrates with the Acme Payments API" matches no pattern, and a subdirectory README is exactly where an integration hides. Record every finding with `file:line` (or `doc:section`) evidence, and list the source and doc files read so an unread one is visible.

   PASS 2 -- MECHANICAL SWEEP (the safety net; tool-side, zero judgment). Run these EXACT patterns (deliberately language-agnostic -- extend per-stack, never shorten) via `scripts/sweep.ps1` over the files in 00-file-manifest.txt, case-insensitive. The script does NOT scan every manifest file -- scanning bulk data on a real repo is what makes the sweep hang (a single .sql dump produced 46k noise matches, one '://'-laden file 10k+). It skips, by design: bulk-data and archive/binary extensions (`sql|sqlite|db|parquet|tar|war|gz|zip|7z|jar|png|pdf|...`), generated/minified/lock files (`*.min.js`, `package-lock.json`, `*.map`, ...), and any file larger than 1 MB -- all of which stay in the manifest for Phase 1 accounting but carry no architecture signal worth the scan cost. It also STREAMS matches and CAPS candidate extraction on a SATURATED pattern (one exceeding ~2000 matches): the true per-pattern count is still recorded and every match site still goes to 00-discovery-raw.txt (accounting is complete), but only the first ~1000 matched lines of a saturated pattern feed the candidate name-harvest -- a pattern matching thousands of times is pervasive noise, not resource localization, and Pass 1 comprehension is the primary discovery method. The three thresholds (`-MaxFileKB`, `-SaturationCap`, `-CandidateCap`) are script parameters you can tune for an unusual repo; a SATURATED line in the output is expected on a large codebase, not an error. The nine patterns:
   - `://`  (every URI and connection string, any protocol/language: https, postgres, redis, mongodb, amqp, s3, ...)
   - `s3|bucket|dynamodb|sqs|sns|kinesis|rds|redis|kafka|rabbitmq|mongo|postgres|mysql|elastic|queue|topic`  (service names, language-agnostic; extend the list if the stack has others, never shorten it)
   - `secret|password|token|api[_-]?key|access[_-]?key|credential`  (secret/credential surfaces)
   - `\.client\(|\.connect\(|new \w+Client|createClient|connectionString`  (client/connection construction)
   - `_URL|_URI|_HOST|_ENDPOINT|_ADDR|_SERVER|_BROKER|_DSN|_QUEUE|_TOPIC|_BUCKET|_TABLE`  (config/env-var KEYS that wire external services -- CRITICAL under PLATFORM-INHERITED infra, where the endpoint is injected at runtime and only the key appears in the repo; catches integrations no URL/hostname pattern can, e.g. a bucket referenced only as `DATA_BUCKET`)
   - `arn:aws`  (AWS resource identifiers; other clouds use the equivalent -- GCP `projects/.../(topics|subscriptions|buckets)`, Azure `/subscriptions/.../resourceGroups/`)
   - `\b(\d{1,3}\.){3}\d{1,3}\b`  (hardcoded IPv4 endpoints; ignore obvious version numbers)
   - `([a-z0-9-]+\.)+(com|net|org|io|cloud|internal|corp|local|gov|mil|edu|us)`  (bare hostnames referenced without a scheme, incl. `.svc.cluster.local` k8s services and government endpoints like `login.gov`; noisiest pattern -- dedupe and keep only host-like matches; extend the TLD list if the org uses others, never shorten it)
   - `getenv|environ\[|process\.env`  (env-var ACCESS calls -- complements the key-suffix pattern above by catching lookups whose key name matches no suffix, e.g. `os.environ["AGENTS"]`)

   These nine patterns are implemented in scripts/sweep.ps1; to extend them per-stack, note the additions in 00-discovery.md and run the extra patterns with Select-String, appending to the artifacts.

   Capture everything in variables and write three artifacts -- no display, no `-First` caps (truncation belongs to exploratory reads only, common.md rule R (cap litmus)), no per-line narration; this whole pass is one code block:
   ```powershell
   $WORKSPACE    = '<the literal WORKSPACE path printed in step 1>'
   $PROJECT_NAME = '<the literal PROJECT_NAME printed in step 1>'
   $OUTPUT_ROOT  = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"
   $SKILL_DIR    = '<the literal SKILL_DIR path given in SKILL.md>'

   & $SKILL_DIR\scripts\sweep.ps1 -Workspace $WORKSPACE -ProjectName $PROJECT_NAME
   ```
   Paste its per-pattern counts and candidates line.
   The artifacts: `00-discovery-raw.txt` is every unique match site WITH its path (a bare line divorced from its file turns a real resource reference into an unrecognizable code fragment -- field-proven); `00-density.txt` ranks files by match count; `00-candidates.txt` is every mechanically-extracted name -- match values, quoted no-whitespace literals, and value tokens after `=` or `:` (resource names never contain spaces, so most prose junk dies in the regex, not in your judgment).

   REFINEMENT -- MERGE THE TWO PICTURES (mandatory, before step 7.5). This is where belt and suspenders check each other:
   (a) Density check: any file in the TOP 10 of 00-density.txt that Pass 1 did not read -- read it now and extract. Matches concentrate where resources live; an unread high-density file is an investigation hole.
   (b) Candidate reconciliation: reconcile every candidate in 00-candidates.txt, but scale HOW you reconcile to the candidate count -- a large repo yields hundreds of candidates even after the sweep's saturation cap, and a row-per-candidate hand-walk does not scale to that. Every candidate ends in exactly one of these dispositions, and the count MUST reconcile (see the tally below), but only the last group needs individual attention:
   - ALREADY-IN-FINDINGS: the candidate is a resource you already found in Pass 1 (exact or clear semantic match). Bulk-count these; do not write a row each.
   - DUPLICATE: a spelling/casing/substring variant of another candidate or finding. Bulk-count.
   - NOISE: mechanically-obvious non-resources -- single common words, language keywords, framework identifiers, file extensions, pure numbers, boilerplate tokens. Bulk-count by this category. You may group noise with a one-line rationale (e.g. "412 noise: language keywords, HTML tag names, and single-word tokens"); do not write a row per noise token.
   - PLAUSIBLE-UNKNOWN (the residual that gets individual treatment): a resource-like name (a service/host/bucket/table/queue/endpoint/secret shape) that is NONE of the above. For EACH of these -- and only these -- run a targeted `Select-String -Pattern '<candidate>'`, read the hit in its file context, and decide: real resource (add to findings) or explained-away (state why). NEVER dismiss a plausible-unknown name unread. This residual is normally small even on a huge repo; if it is itself very large, that is a signal the sweep patterns are matching something structural you should investigate as a group.
   Record in 00-discovery.md a triage TALLY (not necessarily a row per candidate): `candidates: <N> (tool-computed) = already-in-findings <A> + duplicate <B> + noise <C> + plausible-unknown <D>` where `A+B+C+D` MUST equal N (state the arithmetic). Write an individual triage row for each of the <D> plausible-unknowns (that table's row count == D), plus the bulk counts for A/B/C. The invariant is preserved -- every candidate is accounted, and the arithmetic proves none were silently dropped -- but only the plausible residual is investigated one by one.
   (c) Note the findings only Pass 1 produced (nothing mechanical could catch them) -- that is comprehension's contribution and the reason both passes exist.
   State the refinement result verbatim: `candidates: <N> (tool-computed) | accounted: <N> (=already-in <A> + dup <B> + noise <C> + plausible <D>) | rescued by refinement: <N> | Pass-1-only finds: <N> | top-10 density files read: <10/10>`.

   Write everything to `{PROJECT_NAME}-threat-model/00-discovery.md`: the per-pattern match counts, the Pass 1 source/doc file lists, the candidate triage table, the refinement result line, and the merged DISTINCT list of external services / data stores / endpoints / integrations found (Pass 1 finds + rescued candidates), each with `file:line` or `doc:section`. This file -- not memory or judgment -- is the authoritative "what exists" list that scope triages and Phase 1 inventories. Completeness = both passes run, every candidate triaged (counts stated), every doc read -- shown, not felt.

7.5. **Scope completeness self-audit (mandatory, before writing 00-scope.md).** For each element category -- services/processes, data stores, external integrations, secrets/credentials, pipelines/workflows -- answer: have I enumerated every instance by concrete identity, or did I summarize with a count or a generic quantifier? If any category is a count or a generic word rather than a full list, go back and read the relevant files until it is a full list. Then RECONCILE against 00-discovery.md: every distinct external service / data store / endpoint the sweep found MUST appear either in your enumerated in-scope elements OR explicitly marked out-of-scope with a reason -- a discovered item that is neither is a silent drop, the exact failure the sweep exists to prevent. State the audit result: `Enumerated by identity: services <yes>, data stores <yes>, integrations <yes>, secrets <yes>, pipelines <yes>; generic quantifiers remaining: <none | list them and fix>; sweep categories run (per 00-discovery.md): <list>; discovered items unaccounted for (neither in-scope nor consciously excluded): <none | list -- rule violation>`. Note the division of labor: Phase 0 establishes the complete SCOPE (which concrete elements exist and are in bounds); Phase 1 builds the full architectural INVENTORY (their relationships, evidence, and file-level accounting) -- Phase 1 owns the deep inventory, but it can only be as complete as this scope, so do not defer enumeration to Phase 1 on the assumption it will backfill what you left generic here. Finally, reconcile against 00-candidates.txt: every candidate the refinement triaged as a resource MUST appear in the scope as in-scope or out-of-scope-with-reason -- a resource candidate that is neither is a silent drop.

7.6. **Exposure validation (mandatory, after the sweep, before writing 00-scope.md).** Validate the user's Q1 exposure answer against what the sweep and repo map actually surfaced: ingress/edge references (public hostnames, LB/WAF/CDN references, `0.0.0.0` binds, Ingress resources or internet-facing IaC if present in this repo). This is a consistency check on attested facts, not a re-derivation. Record a one-line verdict for 00-scope.md: `Exposure validation: Q1=<answer>; discovery evidence <consistent | CONFLICT: <what the evidence shows>>`. A CONFLICT verdict MUST be surfaced in the step 9 Scope Proposal for the user to adjudicate (the user may know infrastructure this repo cannot show); record their ruling in 00-scope.md. Under PLATFORM-INHERITED infra, thin edge evidence in the repo is normal and is NOT a conflict -- flag a conflict only when found evidence positively contradicts the answer.

7.7. **Write 00-resources.txt (ALWAYS), then archive comparison (completeness cross-check, only when a prior archive exists).** This step has two parts. Part 1 is UNCONDITIONAL and runs on every assessment, including a first run with no prior archive; only Part 2 (the comparison) is gated on a prior archive existing. Do not skip Part 1 just because this is a first run.

   Part 1 (always): write `{PROJECT_NAME}-threat-model/00-resources.txt`: this run's own final DISTINCT resource list in machine-readable form, one per line, two tab-separated columns: `type<TAB>canonical name`, where type is one of `bucket|table|database|queue|topic|cache|agent|external-api|identity-provider|secret-store|service|other`. Its line count MUST equal the distinct-list count in 00-discovery.md (state both, per Operating Rule 15). It is written here, before the comparison below, so this step (and every future run's comparison) has this run's own list on disk -- step 8 below no longer writes it (see the note in step 8).

   Part 2 (only when a prior archived run exists): compare this run's 00-resources.txt against the most recent archive, as follows.

   Find archived run directories using the same discovery pattern SKILL.md's Phase 3 Disposition Discovery uses:
   ```powershell
   $WORKSPACE    = '<the literal WORKSPACE path printed in step 1>'
   $PROJECT_NAME = '<the literal PROJECT_NAME printed in step 1>'
   $OUTPUT_ROOT  = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"
   $SKILL_DIR    = '<the literal SKILL_DIR path given in SKILL.md>'

   $archivedRuns = Get-ChildItem -Path $WORKSPACE -Directory -Filter "$PROJECT_NAME-threat-model-*" -ErrorAction SilentlyContinue
   if ($archivedRuns) {
       $mostRecent = $archivedRuns | Sort-Object LastWriteTime -Descending | Select-Object -First 1
       "most recent archived run: $($mostRecent.Name) (LastWriteTime $($mostRecent.LastWriteTime))"
   } else {
       "no archived runs found"
   }
   ```

   If `$archivedRuns` is empty: state "no prior archived threat-model found -- first assessment, no comparison" in 00-scope.md's summary (do not write 00-archive-comparison.md at all -- there is nothing to compare) and proceed to step 8.

   If one or more archived directories exist, take the most recent by LastWriteTime and compare it against this run:
   ```powershell
   $WORKSPACE    = '<the literal WORKSPACE path printed in step 1>'
   $PROJECT_NAME = '<the literal PROJECT_NAME printed in step 1>'
   $OUTPUT_ROOT  = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"
   $SKILL_DIR    = '<the literal SKILL_DIR path given in SKILL.md>'

   $mostRecent       = Get-ChildItem -Path $WORKSPACE -Directory -Filter "$PROJECT_NAME-threat-model-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
   $priorResources   = Join-Path $mostRecent.FullName '00-resources.txt'
   $currentResources = Join-Path $OUTPUT_ROOT '00-resources.txt'

   if (Test-Path $priorResources) {
       $prior   = Get-Content $priorResources
       $current = Get-Content $currentResources
       $diffSet = Compare-Object -ReferenceObject $prior -DifferenceObject $current -IncludeEqual
       $onlyInPrior   = $diffSet | Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty InputObject
       $onlyInCurrent = $diffSet | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject
       $unchanged     = $diffSet | Where-Object { $_.SideIndicator -eq '==' } | Select-Object -ExpandProperty InputObject
       "comparison basis: 00-resources.txt (both runs)"
       "in prior, not in current (" + $onlyInPrior.Count + "):"
       $onlyInPrior
       "in current, not in prior (" + $onlyInCurrent.Count + "):"
       $onlyInCurrent
       "unchanged (" + $unchanged.Count + "):"
       $unchanged
   } else {
       $priorInventory = Join-Path $mostRecent.FullName '01-inventory.md'
       if (Test-Path $priorInventory) {
           "comparison basis: 01-inventory.md fallback (prior run predates 00-resources.txt) -- weaker basis, component/DS/EXT names only, no type column"
       } else {
           "prior archive has neither 00-resources.txt nor 01-inventory.md -- cannot be compared"
       }
   }
   ```
   When falling back to the 01-inventory.md basis: extract its component/DS-NNN/EXT-NNN names with `Select-String` over the component table rows, and run the same three-way `Compare-Object` against this run's 00-resources.txt name column (the text after the tab on each line) -- name-only, since the older file has no type column. When neither file exists, record in 00-archive-comparison.md that the archive could not be compared and why (no 00-resources.txt and no 01-inventory.md found in it).

   Write the result to `{PROJECT_NAME}-threat-model/00-archive-comparison.md` with the Write tool (common.md rule W): which archived run was compared (name, LastWriteTime), the comparison basis (00-resources.txt, the 01-inventory.md fallback, or "could not be compared" with the reason), and the three named sets in full, not just counts -- in prior/not in current, in current/not in prior, unchanged. This is a completeness cross-check, not an auto-merge: never silently pull a prior run's resource into this run's scope on the strength of this comparison -- every "in prior, not in current" item is surfaced as a question for the user, never merged in automatically.

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
Pass 1 investigation: <N> source files read | <N> docs read | <N> resources found
Pass 2 sweep: <N> candidates (tool-computed) | refinement: <N> accounted, <N> rescued | top-10 density read: <10/10>
Resources: <N> written to 00-resources.txt (line count matches distinct list: yes)
Exposure validation: <consistent | CONFLICT -- see Scope Proposal>
Archive comparison: <no prior archive | compared vs {name}: <N> new, <N> only-in-prior (see Scope Proposal)>
STATE.md updated: phase-0 marked complete.
Present this Scope Proposal to the user and wait for approval or corrections (GATE 1).
```

---

After the user approves the Scope Proposal, run `& $SKILL_DIR\scripts\partition-manifest.ps1 -Workspace $WORKSPACE -ProjectName $PROJECT_NAME` and paste its reconciliation line. The three partition files drive the parallel Phase 1 passes.

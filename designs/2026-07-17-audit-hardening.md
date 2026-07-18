# Design: Code Security Audit executor hardening and coordination loosening

Date: 2026-07-17
Written against: code-security-audit.md on stride-audit-hardening (branched from
stride-v24-merge, commit 192f852). Line anchors below refer to that revision
(1243 lines).

Status: DESIGN ON PAPER. Nothing in this document is built, shipped, or
validated. No item here is fixed until a field run on the work machine confirms
it.

Consumers: (1) future assistant sessions building these changes -- rehydrate
this file instead of re-deriving the argument; (2) the operator hand-typing
edits to the air-gapped machine -- the edit-site lists are the spec;
(3) provenance for why the audit prompt changes the way it does.

Governing document: docs/executor-limitations.md. Every change below is shaped
by its verdict: the executor (Sonnet 4.5, GovCloud Bedrock, 200K) synthesizes
plausible deliverables instead of executing procedures, fabricates
reconciliation numbers it did not compute, and shirks bulk clerical mandates.
What works: numbers computed by tool over on-disk artifacts and pasted,
completeness anchored to objective tool counts, small context-rich judgment
tasks (tens of items), and the human reviewing at gates. Exhortation does not
work and none is added here.

---

## Section 0 -- Review verdict: the #10-#19 backlog is already fixed

All nine open "Audit:" issues (#10, #11, #12, #14, #15, #16, #17, #18, #19)
have fix commits (406d49e, 76b249c, 70a5687, c4a6651, 882114e, 96b5fd2,
d040628, 360da2e) on the deleted stride-v19-arch-findings branch. Verified
2026-07-17: every one of those commits is an ancestor of main, develop, AND
stride-v24-merge (the v20 branch was rebased on top of them), and each fix was
confirmed present in the current file text, not just by ancestry:

- #10: check-the-list wording in both worker banners (lines 526, 585)
- #11: real briefing selection rule (line 711); Medium/Low colors gone (line 942)
- #12: security_architecture_audit.md home declared (lines 182, 337, 879-881)
- #14: partition_status writers assigned (lines 60, 522, 525, 581, 584);
  worker_context.md is a Phase 1 output (lines 352, 365); Phase 5 input (652)
- #15: STATE.md updates are prose instructions before every banner
- #16: Phase 6 not_applicable at init in STANDALONE (lines 233, 336)
- #17: multi_edit gone; target-not-mechanism wording present (line 1211)
- #18: ASCII-only is a GLOBAL RULE (line 66)
- #19: Phase 4A outputs evidence_index.md, READ before WRITE (line 578)

The issues stayed open only because main was force-pushed during the 2026-07-11
branch cleanup, so GitHub's auto-close-on-merge never fired. Disposition: close
each with a one-line verification comment citing this document. No build work.

Also verified clean (do not re-litigate): ledger reason strings, EX-NNN/C-NNN
ID reuse, W4 Attested-mitigated (unverified) semantics, 02-threats.md
references, Priority 1/2 to Critical/High mapping -- all in sync with STRIDE
v24.

---

## Section 1 -- Version stamp and session echo

The audit prompt has no version stamp; STRIDE's stamp (#47) exists because
hand-copied prompts drift invisibly and stale-copy runs masquerade as
regressions. The backlog confusion Section 0 resolves is itself a mild drift
instance.

Edit shape:
- Line 1, above CONTEXT: `PROMPT VERSION: audit-v1 (2026-07-17a)`. The audit
  prompt gets its own series (audit-vN) rather than joining the STRIDE vNN
  series -- the two files version independently and a shared counter would
  imply lockstep releases that do not exist. Letter suffix is monotonic within
  a day, same as STRIDE.
- SESSION START paragraph (line 30): add one sentence -- the first line of
  every session's first response is the version stamp, echoed verbatim. Cheap
  discriminator for "is the work machine's copy current."
- Discipline: bump the stamp (real current date) on every prompt-changing
  commit. Doc-only commits do not bump.

## Section 2 -- Coordination contract fixes

### 2.1 (B1) Phase 2 must route Unverified ledger rows as leads

Line 398 seeds Phase 2 inspection targets from `Code-level` and
`Attested-mitigated (unverified)` rows only. But SEEDED_LEAD_COUNT (line 313)
counts three reasons, and the Phase 3A cross-reference (line 459) expects
`confirms-seeded` matches against `Unverified` rows -- rows that carry the
confirming question the audit exists to answer. As written they can only be
confirmed by accident.

Edit shape: extend line 398 to all three seeded reasons. `Unverified` rows:
the component/files the row names become inspection targets and the row's
confirming question is recorded alongside them in 02_risk_prioritization.md so
Phase 3A sees it at point of use (small context-rich task -- the executor's
strong shape).

### 2.2 (B2) Phase 2 INPUT list is missing its COORDINATED-mode inputs

Phase 2's ACTIONS read the threat model ledger, but INPUT (lines 385-389)
lists neither coordination_mode.md nor {PROJECT_NAME}-threat-model/02-threats.md.
A fail-closed executor refuses; a sloppy one recalls the ledger from chat
memory.

Edit shape: add both to INPUT, marked "(COORDINATED mode only)" consistent
with Phase 3A's style (line 434).

### 2.3 Coordination consent question (user decision, this cycle)

Mode detection (lines 282-295) auto-binds to any complete threat model. Real
workflows need an opt-out: a stale threat model, or deliberately running the
audit unbiased as an independent second mechanism.

Edit shape: when the four-file completeness check PASSES, STOP and ask the
user: "Complete threat model found at <path> (last updated <timestamp>). Run
COORDINATED (cross-reference findings against it) or STANDALONE (independent
audit, no comparison)?" Wait for explicit answer. Record the answer; when the
user declines coordination, coordination_mode.md records MODE: STANDALONE plus
a one-line note that a threat model was present and coordination was declined
(provenance for anyone reading the run later). The STANDALONE path then asks
the deployment-exposure question as it already does (line 324). When the
threat model is absent or incomplete, behavior is unchanged (STANDALONE, no
question). Known consequence, accepted: findings written with null
threat_id/threat_match stay null; producing a comparison later means re-running
in COORDINATED mode.

## Section 3 -- Computed-never-recalled (Rule 15 equivalent) and the date

STRIDE Operating Rule 15 exists because the executor fabricated reconciliation
numbers (executor-limitations, corroborating incident 1). The audit prompt has
no equivalent, and Sections 4-7 below add reconciliations that need it stated
once rather than per-site.

Edit shape:
- New GLOBAL RULE (after the ASCII rule, line 66 block): NUMBERS ARE COMPUTED,
  NEVER RECALLED. Any count, size, or percentage written into a state file,
  banner, or deliverable must be pasted from executed command output over an
  on-disk artifact. If a number cannot be computed by tool, write "not
  computed" rather than an estimate. A stated number with no pasted command
  behind it is a rule violation.
- (B5) Line 189 "get the current date" names no mechanism; Finding IDs
  (F-YYYYMMDD-NNN) and the cross-run log's matching depend on it. Edit: "run
  `Get-Date -Format yyyy-MM-dd` and use its output" -- recalled dates are
  exactly the class the new rule bans.

## Section 4 -- Discovery manifest, partition arithmetic, tier accounting,
## and independent discovery with delta

The largest item. Four connected edits sharing one artifact.

### 4.1 File manifest (tool-generated, Phase 1)

Phase 1's discovery is exploration prose ("Perform full repo scan", line 338)
with no on-disk enumeration -- the pre-W6 shape whose failure history is the
best-documented in the project. The audit does NOT import STRIDE's
read-everything posture (see Section 9); it imports only the cheap part: a
tool-computed enumeration everything downstream reconciles against.

Edit shape: Phase 1, before partitioning: write
audit_state/00_file_manifest.txt via Get-ChildItem -Recurse (excluding .git,
audit_state*, {PROJECT_NAME}-threat-model*, node_modules and standard build
output dirs -- prefix-match, per the STRIDE 4cdaac8 lesson), one line per file:
path TAB size-in-bytes. Paste the total file count and total bytes into the
Phase 1 banner from the command output. This is one command, not a clerical
mandate.

### 4.2 Partition-size arithmetic

Partition triggers (lines 348-351) are judgment ("> 10,000 SLOC"); nothing
sizes a partition against what a Phase 3A session can actually read. Budget
reality on the 200K executor: ~21K tokens prompt + ~15K rehydration + findings
output leaves roughly 100-130K tokens of code-reading capacity. Oversized
partitions force silent shallowing -- the depth failure mode.

Edit shape: partition_plan.md gains a per-partition line: file count and total
bytes, computed from the manifest (Get-ChildItem | Measure-Object -Sum Length
scoped to the partition root, pasted). Threshold guidance: a partition whose
tier-1 + tier-2 reading set exceeds ~400KB of source (rough 100K-token proxy)
must be split, and the split is recorded in partition_plan.md. The number is
computed; the split decision is the model's judgment over a handful of
partitions (tens, not hundreds -- the right side of the sizing line).

### 4.3 (A1/B3) Tier accounting anchored to the manifest

FILE COVERAGE ACCOUNTING (lines 401-405) reconciles tier counts against a
model-written total and explicitly disclaims enforcement ("visibility check,
not a hard gate") -- the assertable-reconciliation class that was
field-falsified in STRIDE (#60). It is also ambiguous about scope: "the
partition" (singular) vs Phase 2 running globally (B3).

Edit shape: the accounting is per-partition, stated explicitly; every
partition gets its own tier table in 02_risk_prioritization.md. The total each
partition reconciles against is its manifest-derived file count from
partition_plan.md (Section 4.2), not a recalled number. The Phase 2 banner
prints one reconciliation line per partition, each pasted:
"partition X: tiered N of M manifest files". Drop the "not a hard gate"
escape sentence: if counts do not match, say so and list the unaccounted
files (the manifest makes the difference computable); do NOT loop re-deriving
tiers. The gate is honesty about the gap, not forced equality.

### 4.4 Independent discovery with reconciliation delta (user decision,
### this cycle)

Line 346 makes the threat model inventory "authoritative -- the audit's
discovery confirms and extends rather than rebuilds." That welds the two
pipelines together at exactly the layer where the top-down pass is known
weakest (discovery misses were the central failure of the whole STRIDE cycle).
An audit that inherits the threat model's component list cannot catch what the
threat model missed, and the comparison's component-coverage check (line 847)
can never flag what neither list contains. Two mechanisms only check each
other if they stay independent.

Edit shape: replace the line 346 clause. In COORDINATED mode Phase 1 builds
its own inventory from its own discovery (manifest + repo scan, as STANDALONE
does), THEN reconciles against {PROJECT_NAME}-threat-model/01-inventory.md and
records a DISCOVERY DELTA section in 01_discovery.md: components/stores/
integrations found by the audit but absent from the threat model inventory,
and vice versa (each direction is a small named list -- tens of items). ID
policy unchanged: where an element matches, reuse the threat model's C-NNN/
DS-NNN/EXT-NNN/TB-NNN verbatim (line 1118 already mandates this); audit-only
elements get new IDs in the same scheme, flagged in the delta. The delta
flows to the Phase 5 comparison's coverage section as threat-model discovery
gaps -- a free ensemble check that inheritance made impossible.

## Section 5 -- Mid-3A/4A resume with a completion anchor

STATE.md already has in_progress for partitions (line 209) but no instruction
for recording partial progress, so a worker session must finish its partition
or lose its place -- and an executor sensing the window filling shallows out
instead of stopping. Depth under a fixed window is bought by adding sessions,
not squeezing sessions; that requires cheap, trustworthy resume.

Edit shape (Phase 3A; Phase 4A inherits identically with
architecture_review.md):

- FILES EXAMINED: security_review.md opens with a "## Files examined" section,
  one line per file actually opened: path -- one-line substantive observation
  ("session handling; no ownership check on GET /users/:id"). Written as a
  by-product of reviewing, not a closing pass. The specific-observation
  requirement is the anti-fabrication texture: fabricated rows read generic,
  and generic rows are what the operator's gate review can spot in seconds
  (STRIDE's ledger-poisoning lesson: a bare read-flag gets batch-flipped).
- PAUSE protocol: when a coherent chunk is done and the window is filling:
  write pending findings to disk (already the rule), update Files examined,
  set the partition to in_progress in STATE.md with Resume Instruction =
  "Resume Phase 3A for partition X; Files examined in
  workers/X/security_review.md; continue with its remaining tier-1/2 files.",
  print a PHASE 3A PAUSED banner variant (same shape as the completion banner,
  PAUSED headline, files-so-far, confirmation line), STOP.
- Resume path: fresh session reads STATE.md, sees in_progress, rehydrates
  worker files; pending = the partition's tier-1/2 list (from
  02_risk_prioritization.md) minus Files examined. Both lists are on disk.
- COMPLETION ANCHOR (the part that makes it real): a partition's 3A is done
  only when every tier-1 and tier-2 file in its 02_risk_prioritization.md
  table appears in Files examined. Verified by two pasted counts
  (Select-String over the two on-disk files) in the completion banner:
  "tier-1/2 files: N; examined: N". Rolled-up-bucket files stay
  pattern-scan-only and are exempt. Without this anchor, resume just
  relocates the shirk to the final session (STRIDE 1B: "remaining files are
  supporting utilities that follow similar patterns").

## Section 6 -- Deliverable completeness reconciliations

### 6.1 (A4) Phase 5: registry count vs report count

"Every finding from findings_registry.md, no exceptions" (line 646, 688) is
enforced by exhortation ("If you find yourself selecting, STOP") -- the
mechanism executor-limitations says does not work. The observed failure is
budget-exhaustion narrowing (line 644), which is precisely a silent count
mismatch.

Edit shape: before the Phase 5 banner, two pasted commands: count finding IDs
in findings_registry.md (Select-String '^id: F-' | Measure-Object), count
distinct F-YYYYMMDD-NNN occurrences in 05_consolidated_report.html. Banner
line: "findings: registry N, report N". Mismatch = report the gap and the
missing IDs (computable by comparing the two Select-String outputs);
regenerate only the missing entries, never the whole file.

### 6.2 (A5) Phase 6: "verified intact" becomes a computed check

Line 987's "after all seven fills complete and the HTML is verified intact" is
an assertable claim with no procedure.

Edit shape: after the fills, paste: Select-String 'COMPARISON-' over
threat_audit_comparison.html | Measure-Object -- remaining placeholder count
must be 0; plus the file's byte size vs the Markdown intermediate's (a
faithful render is the same order of magnitude, not 10x smaller -- a gross
truncation tripwire, not a precision check). Both pasted in the Phase 6
banner before the copy step.

## Section 7 -- Comparison counts computed, not recalled

Every number in the comparison chain is currently model-recalled: the
coordination_mode.md counts (lines 309-313), the Section 1 counts table (line
735), the Section 6 coverage percentages (lines 843-848). This is the
fabricated-reconciliation class verbatim.

Edit shape:
- coordination_mode.md (Phase 1): THREAT_COUNT_MAIN, EXCLUDED_LEDGER_COUNT,
  SEEDED_LEAD_COUNT computed by Select-String over 02-threats.md (main-table
  rows; '^\| EX-' rows; EX rows whose reason starts with the three lead
  prefixes) and pasted.
- Section 1 counts table (Phase 5): each threat_match tally computed by
  Select-String over findings_registry.md ('^threat_match: confirms' etc.),
  pasted; percentages derived from pasted counts only.
- Section 6 coverage: same source counts; component coverage cross-references
  the inventory IDs (Select-String 'C-[0-9]{3}' over 01-inventory.md vs IDs
  appearing in findings/threats).
- All under the Section 3 global rule; these sites just name the specific
  commands so the executor has them at point of use.

## Section 8 -- Disclosure and small fixes

- (A8) AI-generation disclosure: STRIDE Operating Rule 16 (org compliance:
  all AI output labeled) has no audit equivalent. Edit: HTML GENERATION
  REQUIREMENTS (line 858 block) gains the same print-visible disclosure
  banner as first body child on all three stakeholder HTMLs
  (05_consolidated_report.html, executive_briefing.html,
  threat_audit_comparison.html). Markdown/state files stay unlabeled
  (AI-consumed working files), same scoping decision as STRIDE.
- (B4) Phase 4A INPUT (lines 544-552) gains
  audit_state/workers/<partition_id>/worker_context.md (if present) -- 4A runs
  in a fresh session and currently lacks the partition-orientation file 3A
  gets.
- (B6) Phase 5 banners (lines 888-910) list C4_architecture.md and the
  security_architecture_audit.md update, so a session that skipped them cannot
  print a complete-looking banner.
- Line 336 init list gains EXECUTOR_MODEL (line 233 has it; 336 omits it).
- STATE.md schema gains EXECUTOR_HARNESS (continue.dev | claude-code |
  other/unknown) alongside EXECUTOR_MODEL, same self-report-or-unknown rule
  and same rationale: during the dual-harness transition (Section 9.5) the
  harness is a second silent variable in any cross-run comparison, and it
  becomes unrecoverable once a run is done.
- Phase 6 Step 3 copy (line 985-991) names its mechanism: Copy-Item, with the
  existing do-not-modify-other-files caveat retained.
- Environment assumptions (line 5) add Claude Code CLI alongside Continue.dev
  as a supported agent harness (Continue.dev is being retired from the work
  environment; Claude Code CLI is now available there, though initial field
  testing of this design still runs on Continue.dev).
- CROSS-PROMPT FIX (stride-threat-model-prompt.md, found 2026-07-17 while
  reviewing directory naming): the Phase 0 manifest exclusion lists
  `audit_state` in $topLevelExcludeExact (line 266) -- EXACT match only. The
  audit's archive model renames the directory to audit_state-YYYYMMDD, which
  escapes an exact match, so an archived audit directory gets swept into a
  later STRIDE run's file manifest and treated as source (findings and secret
  locations included). Same bug class as 4cdaac8, opposite direction. Fix:
  match audit_state by prefix (move it to prefix handling alongside
  $topLevelExcludePrefix), and note archived dirs in Rule 13a's wording.
  This is a live defect and ships in this cycle; it is one line and does not
  conflate the field-test variables.

## Section 9 -- Deliberately not doing (and why)

- NO read-every-file contract for 3A/4A workers. Bulk clerical mandates get
  shirked or faked (executor-limitations incidents 1-3). The audit's tiered,
  risk-weighted depth is correct FOR AN AUDIT: it has a Critical/High severity
  floor and precision-over-coverage by design, unlike STRIDE Phase 1 where an
  inventory miss erases threats downstream. The Section 5 completion anchor
  covers exactly the files Phase 2 judged worth reading -- that is the
  contract, and it is enough.
- NO per-line disposition ledgers or other STRIDE-v23-style clerical bolt-ons.
  Field-tested; they displaced the organic reading that performs.
- NO prompt slicing. The audit prompt is ~85K chars (~21K tokens), half of
  STRIDE; the win is small and slice files multiply hand-copy version drift.
  The Claude Code skill conversion supersedes this natively.
- NO Section 3 (unconfirmed threats) slimming yet. Suspected noise
  ("architectural, cannot observe" boilerplate), but no field evidence; per
  no-premature-victory, wait for a coordinated field run to show it.
- NO full STANDALONE discovery hardening beyond the manifest. COORDINATED
  mode (the actual usage) now gets independence via 4.4; a STRIDE-grade
  discovery pipeline for standalone audits is a future piece if standalone
  usage materializes.
- NO output-directory rename this cycle -- but the direction is DECIDED for
  the skill conversion: audit_state/ becomes {PROJECT_NAME}-security-audit/.
  Rationale: the current name labels the mechanism while holding the
  stakeholder deliverables, and it breaks symmetry with
  {PROJECT_NAME}-threat-model/ (project-prefixed, product-named, prefix-
  matched archives). Not done now because the name is hardcoded across every
  audit phase AND three load-bearing STRIDE sites (Rule 13a, manifest
  excludes, Phase 1 exclusions), and bundling a rename into this cycle's
  field runs conflates variables. The cross-run log stays at workspace root
  either way (placement is load-bearing: it must survive run-dir archiving).
  The skill conversion re-plumbs paths anyway; adopt the new name there,
  updating both prompts in the same commit per the cross-prompt guard.

## Section 9.5 -- Skill-era forward compatibility (Claude Code CLI)

Context (2026-07-17, from the operator): Continue.dev is no longer developed
and will be retired from the work environment; Claude Code CLI is now
available there. Initial field testing of THIS design still runs on
Continue.dev. Future versions of the audit prompt will become a Claude Code
skill (per-phase reference files, progressive disclosure), the same strategic
direction already recorded for STRIDE. docs/executor-limitations.md remains
the requirements document for that conversion.

Design rule adopted because of this: every mechanism this design ADDS is an
artifact contract plus a harness-neutral PowerShell computation. No new edit
may reference Continue.dev-specific tool names (create_new_file,
single_find_and_replace); those already in the prompt are inherited text, out
of scope here, and become a conversion-time substitution (Claude Code
Write/Edit tools).

Fate map for the conversion (methodology carries over; enforcement upgrades):

- Section 1 stamp/echo: KEEP through transition -- the air gap means the
  skill still travels by hand until installed and versioned on the work
  machine; drift protection stays live. Skill-era: version lives in skill
  metadata, echo becomes trivial.
- Section 2 coordination contract + consent question: pure methodology, KEEP.
- Section 3 computed-never-recalled + Sections 6/7 reconciliations:
  methodology (the artifact contracts and which numbers matter) KEEPS; the
  computation moves from model-executed-and-pasted to skill scripts/ or hooks
  that compute and verify. The pasted-count discipline is the interim
  enforcement, not the end state.
- Section 4 manifest/partition arithmetic/tier accounting/delta: artifacts
  KEEP; manifest and size computations become a script. Partition thresholds
  were calibrated to full-prompt-paste overhead (~21K tokens); under
  progressive disclosure they become conservative, which is safe.
- Section 5 resume + completion anchor: the Files-examined artifact and PAUSED
  protocol KEEP as the resume spine (STATE.md architecture carries over
  unchanged). The prose completion anchor is explicitly the INTERIM mechanism:
  Claude Code hooks can count actual Read tool calls per manifest file and
  block the phase gate -- the structural enforcement executor-limitations.md
  says prose cannot achieve. When hooks exist, the anchor's pasted-count text
  is superseded, not the artifacts.
- Section 8 disclosure: methodology, KEEP.
- Section 9 exclusions STRENGTHENED: prompt slicing is natively superseded by
  progressive disclosure; clerical enforcement bolt-ons have hooks as their
  correct home, so none should be added to prompt text now.

Constant across the transition: Sonnet 4.5 and the 200K window are
model-bound, not harness-bound. The partition arithmetic and resume design
keep their value under Claude Code until the ~Sep 2026 model unlock.

### Transition sync model (dual-harness period, expected 1-2 months)

Operator constraint: Continue.dev and Claude Code will BOTH be in use during
the conversion window, with prompt changes still landing; there is no clean
cutover date. The sync rule that survives this: AT ANY MOMENT, EACH PROMPT HAS
EXACTLY ONE EDITABLE SOURCE; every other form is generated. Never two
hand-edited copies.

- Phase 1 (now, through field validation of this design): no conversion. The
  monolith is the single source; Continue.dev is the test bed. Do not convert
  a prompt while it is mid-hardening.
- Phase 2 (per prompt, at conversion): restructure the SOURCE into per-phase
  skill files and DEMOTE the monolith to a build artifact -- a PowerShell
  script concatenates phase files plus a Continue.dev preamble adapter (tool
  tables, session-start scaffolding) into the monolith, injecting the same
  version stamp into every output. Editing happens in phase files only.
  Claude Code consumes the skill; Continue.dev consumes the generated
  monolith, hand-copied as today. Cross-harness sync = re-running the build,
  and the existing session-start stamp echo detects a stale copy exactly as
  it does now.
- Concatenation (skill files -> monolith) is deliberately the build
  direction, not splitting: it is the trivially robust operation, and it
  makes cutover a non-event -- cutover is the day the build stops being run.
- Conversion order: STRIDE first (largest progressive-disclosure win, stable
  post-v24 methodology; converting it teaches the build pattern). The audit
  prompt converts only AFTER this design's changes field-validate on
  Continue.dev -- a first skill release must not bundle unvalidated prompt
  changes, or harness effects and prompt effects become inseparable.
- The Section 9.5 no-new-harness-specific-tool-names rule is what keeps phase
  text harness-neutral enough for the preamble-adapter split; the inherited
  create_new_file / single_find_and_replace references inside phase text are
  the main conversion-time chore (move to adapter or rephrase neutrally).

## Section 10 -- Build order and commit discipline

One commit per numbered item, smallest first, stamp bumped each time
(audit-v1 dates advance with real dates; letter suffix within a day):

1. Section 1 -- version stamp + session echo (first, so every later commit
   bumps it)
2. Section 2 -- B1 + B2 + consent question (coordination contract)
3. Section 3 -- computed-never-recalled rule + Get-Date
4. Section 4 -- manifest, partition arithmetic, tier accounting, discovery
   delta (may split into 4.1+4.2 / 4.3 / 4.4 commits if edits run large)
5. Section 5 -- mid-3A/4A resume + completion anchor
6. Section 6 -- Phase 5/6 reconciliations
7. Section 7 -- comparison counts
8. Section 8 -- disclosure + small fixes

Branch: stride-audit-hardening (off stride-v24-merge -- the audit file's
current state, including W4 edits, exists only there). Merge sequencing:
stride-v24-merge -> develop must land first; this branch queues behind it.
Never commit to develop/main directly.

Cross-prompt contract guard: nothing in this design changes ledger reason
strings, dispositions.csv schema, or ID schemes. Any future edit that touches
those must be applied to both prompts in the same commit.

Validation stance: every item above is built-untested until a work-machine
field run exercises it. The likeliest regression risks, for the field run to
watch: (a) Section 4.4's independent discovery costs Phase 1 context -- if
Phase 1 sessions start exhausting, the delta may need its own sub-phase;
(b) Section 5's Files-examined notes could drift toward generic filler --
check them at the first gate review; (c) the consent question adds one more
interactive stop -- confirm it does not tempt the executor into improvising
menus (the #25 class).

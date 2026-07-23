# Carve verification -- Task 10

Carve source: `git show 192f852:stride-threat-model-prompt.md` (1370 lines), byte-identical
to `.superpowers/sdd/v24-frozen.md` (diff confirmed empty). Skill under review:
`skills/stride-threat-model/` on branch `stride-v25-skill`.

## Part A -- Operating Rule reference reconciliation

Grep for `Operating Rule` across the whole skill directory, before any fix:

| File | Line | Reference | Status |
|---|---|---|---|
| references/phase-1c.md | 6 | Operating Rule 9 | KEPT -- valid |
| references/phase-1-reconcile.md | 49 | Operating Rule 5 | KEPT -- valid |
| references/phase-0.md | 100 | Operating Rule 2 | KEPT -- valid |
| references/phase-0.md | 114 | Operating Rule 2 (x2) | KEPT -- valid |
| references/phase-0.md | 122 | Operating Rule 9 | KEPT -- valid |
| references/phase-0.md | 137 | **Operating Rule 6c** | DANGLING -> fixed |
| references/phase-0.md | 156 | Operating Rule 9, Operating Rule 15 | KEPT -- valid |
| references/phase-0.md | 158 | Operating Rule 15 | KEPT -- valid |
| references/common.md | 12 | "Operating Rules" (section heading, not a numbered cite) | not a reference -- left alone |
| references/common.md | 57 | **Operating Rule 12** | DANGLING -> fixed |
| references/phase-1-shared.md | 7 | Operating Rule 13 | KEPT -- valid |
| references/phase-1-shared.md | 9 | Operating Rule 9 | KEPT -- valid |
| references/phase-1-shared.md | 18 | **Operating Rule 6** (bare) | DANGLING -> fixed |
| references/phase-2c.md | 51 | Operating Rule 2 | KEPT -- valid |
| references/phase-2c.md | 100 | **Operating Rule 7(d)** | DANGLING -> fixed |
| references/phase-3-csv.md | 45 | Operating Rule 14 | KEPT -- valid |
| references/phase-3-csv.md | 46 | **Operating Rule 7** (bare, decision table) | DANGLING -> fixed |
| references/phase-2b.md | 43 | Operating Rule 2 | KEPT -- valid |
| references/phase-2b.md | 73 | Operating Rule 2 | KEPT -- valid |
| references/phase-2b.md | 83 | Operating Rule 4 | KEPT -- valid |
| references/phase-2b.md | 95 | Operating Rule 2 | KEPT -- valid |
| references/phase-2b.md | 121, 123 | Operating Rule 2 | KEPT -- valid |
| references/phase-2b.md | 170 | Operating Rule 14, Operating Rule 16 | KEPT -- valid |
| references/phase-2b.md | 172 | **Operating Rule 7(d)** | DANGLING -> fixed |
| references/phase-3-html.md | 23 | **Operating Rule 7** (bare, decision table) | DANGLING -> fixed |
| references/phase-3-html.md | 35, 36 | Operating Rule 14, Operating Rule 16 | KEPT -- valid |
| references/phase-3-html.md | 101 | **Operating Rule 7(d)** | DANGLING -> fixed |
| references/phase-4.md | 69 | Operating Rule 16 (Rule 16 bare on second mention -- not the "Operating Rule" pattern) | KEPT -- valid |
| references/phase-4.md | 87 | Operating Rule 15 | KEPT -- valid |

No hits at all in phase-1a.md, phase-1b.md, phase-2a.md, phase-3-dispositions.md, SKILL.md,
install.ps1, or scripts/*.ps1.

**Fixes applied (before -> after):**

| File | Before | After |
|---|---|---|
| references/common.md:57 | `Operating Rule 12` | `the STATE.md schema in SKILL.md` |
| references/phase-0.md:137 | `Operating Rule 6c` | `common.md rule R (cap litmus)` |
| references/phase-1-shared.md:18 | `Operating Rule 6` | `common.md rule R` (bare 6 -- not explicitly named in the task's 3-pattern list, but 6 is not a kept number and this sentence is the reading-tools instruction rule R replaced; treated as dangling on the same basis as 6c) |
| references/phase-2b.md:172 | `Operating Rule 7(d)` | `common.md rule W-d` |
| references/phase-2c.md:100 | `Operating Rule 7(d)` | `common.md rule W-d` |
| references/phase-3-csv.md:46 | `Operating Rule 7` | `common.md rule W` |
| references/phase-3-html.md:23 | `Operating Rule 7` | `common.md rule W` |
| references/phase-3-html.md:101 | `Operating Rule 7(d)` | `common.md rule W-d` |

Re-grep after fixes: `Operating Rule (6|7|12)\b` across the whole skill dir -> zero hits.
Every remaining `Operating Rule N` reference resolves to a number common.md actually kept
(2, 3, 4, 5, 8, 9, 10, 13, 13a, 14, 15, 16).

## Part A2 -- S4 STATE.md-ownership wording normalization

Grep for `STATE.md` / `orchestrator-owned` before fix found 8 occurrences of the ownership
sentence, in two non-conforming forms:

- `references/common.md:50` -- `STATE.md is orchestrator-owned: never write it.` (colon
  form, different verb) -> normalized to `STATE.md is orchestrator-owned. Do not
  read-modify-write it.`
- `references/phase-1-reconcile.md:109` -- `STATE.md is orchestrator-owned. Do not
  read-modify-write it; the orchestrator marks phase status.` (semicolon-joined, so the
  required sentence did not appear as its own sentence ending in a period) -> normalized to
  `STATE.md is orchestrator-owned. Do not read-modify-write it. The orchestrator marks phase
  status.` (extra clause retained per the exception).

The other 6 occurrences (phase-4.md:15, phase-3-html.md:13, phase-3-csv.md:13,
phase-2c.md:11, phase-2a.md:11, and phase-2b.md:11 which has a longer trailing clause) were
already exact. Re-grep after fix: all 8 occurrences now start with the exact required
sentence.

## Part A3 -- Script header order

All four `scripts/*.ps1` had the file-path banner on line 1 and `# SKILL VERSION` on line 2.
Swapped in all four (manifest.ps1, sweep.ps1, partition-manifest.ps1, validate-drawio.ps1).
Verified with `Get-Content -TotalCount 2`: SKILL VERSION is now line 1, banner line 2, in
every script including the new concat-monolith.ps1.

## Part B -- concat-monolith.ps1

Created `skills/stride-threat-model/scripts/concat-monolith.ps1`. ASCII-only (verified: 0
bytes > 127 in the script source). SKILL VERSION comment on line 1. Ran with
`-OutFile <scratchpad>\stride-threat-model-concat.md`:

```
Wrote <scratchpad>\stride-threat-model-concat.md
Size (bytes): 150315
Line count: 1237
```

(Note: the script's first line-count implementation used `Measure-Object -Line`, which
under-counted -- 871 vs. a true count independently confirmed by a raw-byte LF scan and by
`Get-Content | .Count`. Fixed to `@(Get-Content $OutFile).Count` before this run. Numbers
above are from the final run, after the Part D/E banner fixes were applied -- an earlier run
before those fixes reported 149385 bytes / 1213 lines.)

First line of output is exactly:
`BUILD ARTIFACT -- generated by concat-monolith.ps1 from v25-skill; the skill files are canonical`

## Part C -- Mechanical scans

**C1.** `create_new_file|single_find_and_replace|Continue\.dev|edit_existing_file` across all
skill files: **zero hits**. Case-insensitive `type 'proceed'`: **zero hits**. (Legitimate
`DO NOT PROCEED UNTIL...` prose was not touched -- confirmed it doesn't match this pattern.)

**C2.** Every `references/*.md` has exactly one `SKILL VERSION` line (14 files, 14 hits, one
each). `SKILL.md` has one version-comment line (line 5) plus one unrelated prose mention at
line 19 (`Print exactly one line: "Running stride-threat-model SKILL VERSION: <stamp
above>"` -- an instruction referencing the stamp, not a second stamp). Treated as compliant.

**C3.** ASCII scan across every file in `skills/stride-threat-model/`:

- `references/phase-4.md`: 27 non-ASCII bytes -- expected, the Operating Rule 14 `.drawio`
  exception glyphs (lock/warning/checkmark).
- `references/common.md`: **25 non-ASCII bytes -- NOT anticipated by the task's framing**.
  Investigated: these are the literal example characters inside Rule 14 itself (em-dash,
  en-dash, arrows, smart quotes, ellipsis, and the same three `.drawio` exception glyphs) --
  Rule 14 has to show the actual banned Unicode characters to explain what to substitute.
  Byte-for-byte diffed the surrounding block (common.md lines 91-101) against the frozen
  monolith (lines 145-155): **identical**. This is carved-verbatim, correct content, not
  corruption -- Rule 14 could not state its own substitution table in ASCII-only prose
  without quoting the very characters it bans. Left unchanged. **Finding for the requester**:
  the "only phase-4.md is allowed non-ASCII" assumption in this task's brief is incomplete;
  common.md legitimately needs it too, for this one rule's illustrative table.
- All other files (SKILL.md, install.ps1, remaining references/*.md, all scripts/*.ps1):
  0 non-ASCII bytes.

## Part D -- Word-diff verification, per file

Method: extracted each frozen line range verbatim with `sed -n`, stripped the leading
`<!-- SKILL VERSION -->` comment line from each carved file, and ran
`git diff --no-index --word-diff` between the two. Hunk counts below are `@@` markers in the
unified diff; "substitution" and "structural addition" labels reference the task's known
categories (S1-S8, A1/A2 from this task, plus the named structural additions).

| File | Frozen range | Hunks | Hunk classification | Verdict |
|---|---|---|---|---|
| common.md | L4-7,11-13,19-27,29,31,33,73-98,100,102,139,141,143-155,157,159-164 | 4 | heading rename (structural); new rules R/W/X (structural addition, per task-2-brief); A1 fix (Rule 12 -> STATE.md schema in SKILL.md, this task); S7 (session-management parenthetical deleted from Rule 9's neighbor -- carried in phase-0.md instead, see below) | PASS |
| phase-0.md | L187-404 | 7 | S1 (read_file->Read), S2 (create_new_file->Write tool), S8 (PowerShell inlined -> "Run the extracted script and paste its output", pointing at scripts/sweep.ps1 and scripts/manifest.ps1), A1 (Rule 6c -> common.md rule R (cap litmus); Rule 7 -> common.md rule W), S5 (proceed banner -> return/present-to-user banner), structural addition ((ORCHESTRATOR-RUN) tag, partition-manifest.ps1 call appended after Scope Proposal) | PASS |
| phase-1-shared.md | L424-439,443 | 2 | S6 (Continue.dev `read_file`/`ls` phrasing removed), A1 (Rule 6 -> common.md rule R), structural addition (Partition Contract, Partial Inventory Schema) | PASS |
| phase-1a.md | L441-452 (minus 443) | 2 | structural addition (rehydration line, trailing "write partial + return remaining files" instruction) | PASS |
| phase-1b.md | L456-463 | 2 | structural addition (rehydration line, trailing write/return instruction) | PASS |
| phase-1c.md | L465-476 | 2 | structural addition (rehydration line, trailing write/return instruction) | PASS |
| phase-1-reconcile.md | L478-554,556,560 | 2 (+1 after this task's fix) | structural addition (Reconciliation Procedure, rehydration line); S5/orchestrator-move (System Restatement: subagent now drafts + returns it instead of asking the user directly, since subagents can't ask); A2 (STATE.md sentence normalized, this task) | PASS (see confirmed-loss note below -- fixed) |
| phase-2a.md | L585-675 | 2 | S1, S2, S4 (STATE.md ownership sentence), S5 (proceed->return banner) | PASS |
| phase-2b.md | L679-868 | 4 | S1, S2, S4, S5, A1 (Rule 7(d) -> common.md rule W-d) | PASS |
| phase-2c.md | L872-992 | 5 | S1, S2, S3 (single_find_and_replace->Edit tool), S4, S5, A1 | PASS |
| phase-3-dispositions.md | L1079-1103 | 2 | structural addition (rehydration line via Read tool; "write matched/not-transferred + return match report line" closing paragraph, table header) | PASS |
| phase-3-html.md | L998-1015+1105-1187 | 2 (+1 after this task's fix) | S1, S2, S4, A1 (Rule 7 -> common.md rule W; Rule 7(d) -> common.md rule W-d); structural addition (dispositions-matched rehydration sentence) | PASS (see confirmed-loss note below -- fixed) |
| phase-3-csv.md | L998-1015+1189-1218 | 2 (+1 after this task's fix) | S1, S2, S4, A1; structural addition (dispositions-matched rehydration sentence) | PASS (see confirmed-loss note below -- fixed) |
| phase-4.md | L1233-1353+1357-1370 | 3 | S1, S2, S3, S4, S5, S8 (validate-drawio.ps1 call replaces inlined PowerShell); structural addition/rename (heading "Archiving for Future Runs" -> "Archiving Reminder", content now returned to orchestrator to print instead of a manual step) | PASS |

Every hunk in every file maps to a documented substitution or a documented structural
addition. No hunk introduced unexplained content drift.

### Confirmed losses found during Part D/E, and fixes applied

Three files, all phase-boundary/deliverable files, were missing the completion-banner
template that every other terminal phase file carries (phase-0, phase-2a, phase-2b, phase-2c,
phase-4 all have one; common.md rule X requires every subagent to return "the phase
completion banner" in its summary). These are genuine nuance losses from the carve, not
intentional drops -- nothing in the substitution table or the structural-addition list
accounts for removing a completion banner.

1. **phase-1-reconcile.md** was missing the frozen Phase 1 Completion Banner (frozen
   L562-571, minus the `Type 'proceed'` line per S5). Fixed: added a "Phase 1 Completion
   Banner" block (component/TB/assumption counts, file coverage, System Restatement status,
   STATE.md line, "return this banner verbatim") after the completion-gate paragraph.
2. **phase-3-html.md** and **phase-3-csv.md** were both missing a completion banner. In the
   frozen monolith Phase 3 was one agent producing both files with one combined banner
   (frozen L1222-1229); the skill splits Phase 3 into two independent parallel agents, and
   neither inherited a banner. Fixed: added a minimal "Phase 3A Completion Banner" to
   phase-3-html.md and "Phase 3B Completion Banner" to phase-3-csv.md, each reporting the
   threat count and priority breakdown already required by that file's own rehydration
   acknowledgment step. Neither banner claims "STATE.md updated: phase-3 marked complete"
   (unlike the single-agent banners) because phase-3 in STATE.md is one status entry gated on
   *both* parallel agents finishing -- same non-claim pattern already used by phase-1a/1b/1c,
   which don't declare phase-1 complete individually either.

All three fixes are included in this task's commit.

## Part E -- Coverage-of-source check (frozen L1-L1370)

Computed programmatically: unioned every carve range from Part D against the full 1-1370
line span; the complement is the gap set below. Every gap line was read from
`.superpowers/sdd/v24-frozen.md` and classified.

| Gap range | Content | Disposition |
|---|---|---|
| L1-3 | Version-stamp comment, `PROMPT VERSION` line, blank | Replaced -- SKILL.md carries its own `SKILL VERSION` line (SKILL.md:5) and Session Start prints it |
| L8-10 | blank, Continue.dev built-in-tools paragraph, blank | S6 -- Continue.dev scaffolding deliberately dropped |
| L14-18 | Operating Rules heading (old wording) + Rule 1 "Phase discipline" + blank | Heading renamed into common.md:12; Rule 1 is orchestrator-owned -- covered by SKILL.md Session Start / Gates (three-gates vs. all-gates policy) |
| L28, L30, L32, L34 | blank lines between kept rules 2/3/4/5 | whitespace only |
| L35-53 | Rule 6 full text (Continue.dev read-tool priority order, cap litmus) | S6 removed; cap-litmus concept preserved and generalized into new Rule R |
| L54 | blank | whitespace |
| L55-71 | Rule 7 full text (write decision table, create_new_file/single_find_and_replace) | S2/S3 removed; replaced by new Rule W |
| L72 | blank | whitespace |
| L99, L101 | blank lines around Rule 9 | whitespace |
| L103-105 | Rule 11 "When uncertain, stop and ask" + blank | Orchestrator-owned -- generalized into common.md rule X (subagent STOP-and-return) plus Phase 0's interactive nature in SKILL.md |
| L106-138 | Rule 12 "STATE.md is the resume signal" + full v24 STATE.md schema | Moved verbatim in spirit to SKILL.md's "STATE.md (you are its ONLY writer)" section (v25-compatible schema, two added header lines) |
| L140, L142, L156, L158 | blank lines around rules 13/13a/14/15 | whitespace |
| L165-186 | blank + "Session-Start Behavior" section (STATE.md check, version-print, resume/restart prompt) | Moved to SKILL.md's "Session Start" section |
| L405-423 | Phase 1 heading + old Phase 1 Rehydration (full-manifest `read_file` reads) + "mark phase-1 in-progress" | Superseded by the Partition Contract design (phase-1-shared.md + partition-specific rehydration in 1a/1b/1c); STATE.md marking is orchestrator-owned (SKILL.md's generic in-progress/complete rule) |
| L440, L464, L477 | blank lines around Phase 1A/1B/1C headings | whitespace |
| L453-455 | blank, "Pass order" sequencing advice (1B vs 1C first), blank | Deliberately obsolete -- 1A/1B/1C now run in one parallel group (SKILL.md dispatch table), so there is no serial order left to advise on |
| L555, L557-559 | blank + "update STATE.md: mark phase-1 complete..." + blank | Orchestrator-owned, dropped |
| L561 | blank | whitespace |
| L562-571 | **Phase 1 Completion Banner** | **Confirmed loss -- fixed this task** (see Part D note) |
| L572-574 | blank, `---`, blank | whitespace/separator |
| L575-581 | Phase 2 heading, intro paragraph, sub-phase bullet list (2A/2B/2C -> file mapping) | Structural -- redundant with the file split itself (phase-2a.md/2b.md/2c.md existing as separate files) plus SKILL.md's dispatch table |
| L582 | blank | whitespace |
| L583 | Phase 2 cross-session resumability paragraph | Generalized -- covered by SKILL.md's "You die mid-run: STATE.md is the spine..." (Failure handling) |
| L584 | blank | whitespace |
| L676-678, L869-871, L993-995, L1354-1356 | blank/`---`/blank between phase headings | whitespace/separator |
| L996-997 | Phase 3 heading + blank | Structural -- redundant with the phase-3-html.md/phase-3-csv.md/phase-3-dispositions.md split |
| L1016-1078 | "Phase 3 Disposition Discovery" (Steps 1-3, Cases A/B/C) | Orchestrator-owned -- moved verbatim in substance to SKILL.md's "Phase 3 Disposition Discovery (YOU, before group B)" (Case A/B/C preserved) |
| L1104, L1188 | blank | whitespace |
| L1219-1221 | "update STATE.md: mark phase-3 complete..." + blank | Orchestrator-owned, dropped |
| L1222-1229 | **Phase 3 Completion Banner** (combined HTML+CSV) | **Confirmed loss -- fixed this task**, split into separate 3A/3B banners (see Part D note) |
| L1230-1232 | blank, `---`, blank | whitespace/separator |

**Result: zero unaccounted ranges remain.** 263 gap lines total; all resolve to whitespace/
separator formatting, a documented substitution (S1-S8), content that migrated to SKILL.md as
orchestrator-owned, or one deliberately-obsolete paragraph (Pass order, superseded by
parallel execution). The two genuine losses found (Phase 1 and Phase 3 completion banners)
were fixed before this commit; no content was silently dropped.

## Overall verdict

**PASS**, with two confirmed-and-fixed nuance losses (missing completion banners on
phase-1-reconcile.md, phase-3-html.md, phase-3-csv.md) and one documentation correction
(common.md legitimately contains non-ASCII bytes in Rule 14's own substitution-table
examples; the "only phase-4.md" framing in this task's brief was incomplete, not the skill).

## Known-carried defects (pre-existing in frozen v24, deliberately NOT fixed)

Reason for all: the conversion freezes methodology at v24; these are pre-existing source
defects to fix in a later methodology change, not during the port.

> NOTE (v25): the Phase 4 empty-trust-boundary-container defect surfaced by the Task 13
> Phase 4 smoke test (three of six trust boundaries rendered as EMPTY containers on the
> fixture, plus a 4640px over-wide canvas) is **FIXED-in-v25**, not carried. It was never
> a frozen-v24 methodology bug worth freezing around: the Phase 4 layout was intentionally
> revised beyond v24 under the skill owner's explicit field feedback -- see
> "## v25 enhancements beyond v24" below.

1. **phase-2c.md**: prose says write the Excluded Threats Ledger as the LAST section of
   02c-assumptions.md ("write it as the LAST section of 02c-assumptions.md"), but the
   blueprint schema places it third of seven sections (Threat Filtering Summary, Excluded
   Threat Categories, Excluded Threats Ledger, then Control Coverage Summary, Questions
   for Stakeholders, Assumptions Made, and Coverage and Known Gaps follow it). This is a
   prose-vs-blueprint contradiction; the blueprint wins in generation because the schema
   fence is what an agent actually follows when writing the file. Frozen source L933
   (`git show 192f852:stride-threat-model-prompt.md`, same line in the carved
   phase-2c.md).
2. **phase-3-html.md**: several mandatory HTML requirements -- the Reviewer metadata
   block, the sticky left-sidebar TOC, the Disposition `<select>`/`<textarea>` form
   controls, the RevisedPriority control, and the `Export dispositions.csv` button -- are
   specified in prose OUTSIDE the numbered mandatory-sections list (the "Sections in
   order... every numbered section below is MANDATORY" list). An agent that treats only
   the numbered list as the completeness contract can miss these because they are
   structurally outside it, even though the surrounding prose also uses MANDATORY-style
   language.

The three items below surfaced from the Task 11 Stage 1 smoke test (real execution of
Phase 0 against a fixture repo -- see `.superpowers/sdd/task-11-stage1-report.md`). Each
is a source pattern or template carved verbatim from frozen v24, not something the
conversion introduced, so per the same reasoning as items 1-2 they are documented here
and left unfixed rather than corrected during this conversion.

3. **sweep.ps1 / phase-0.md Pass 2, bare-hostname pattern**: the TLD alternation
   `([a-z0-9-]+\.)+(com|net|org|io|cloud|internal|corp|local|gov|mil|edu|us)` has no
   trailing word boundary, so `.us` (the United States ccTLD) false-matches ordinary
   identifiers shaped like `<word>.us...` -- e.g. `request.user_id` in Python produces
   the spurious candidate `request.us`. This adds junk candidates the refinement step
   must triage one at a time (rule: never dismiss a name unread), which on a larger repo
   with many `.user`/`.usage`/`.used`-style identifiers scales into a proportionally
   large amount of noise. Frozen source pattern, Phase 0 Pass 2.
4. **phase-0.md Phase 0 Completion Banner, hardcoded "10/10"**: the banner template
   line reads `top-10 density files read: <10/10>`, which is inapplicable on any repo
   small enough that fewer than 10 files register any sweep match at all -- common for
   small fixture or microservice repos. The true denominator should be substituted
   (e.g. 9/9), not the literal template text.
5. **00-resources.txt fixed type vocabulary, no type for an individual secret or an
   IAM role/policy**: step 7's Pass 1 instruction and step 7.5's self-audit both require
   enumerating secrets/credentials and services by concrete identity, but the
   00-resources.txt controlled type vocabulary
   (`bucket|table|database|queue|topic|cache|agent|external-api|identity-provider|
   secret-store|service|other`) has no `secret`/`credential` type for an individually
   discovered secret value (only `secret-store`, a secret-management service like
   Vault), and no clean type for an IAM role or policy either. Both end up documented
   only in prose (00-discovery.md / 00-scope.md) rather than as 00-resources.txt rows,
   since none of the 11 controlled types fit.

The two items below surfaced from the Task 11 Stage 2 smoke test (real execution of
Phase 1B against a fixture repo -- see `.superpowers/sdd/task-11-stage2-log.md`). Each
is verbatim from frozen v24 / inherent to the source methodology, not something the
conversion introduced, so per the same reasoning as items 1-5 they are documented here
and left unfixed as out of scope for this port.

6. **Component "Type" enum is open-ended**: the enum (`web-app | api-service | worker
   | database | cache | queue | managed-service | gateway | identity-provider |
   external-saas | cli | job | lambda | frontend-spa | ...`) ends in an open "...", with
   no guidance on how to extend it. This is in tension with Operating Rule 5's
   determinism requirement ("Deterministic IDs... stable across re-runs"): two
   independent runs can label the same element with two different extension values
   (e.g. one run choosing "ci-cd-pipeline" and another choosing something else for the
   same CI/CD workflow file), which shows up as a spurious diff on re-run even though
   nothing about the element itself changed.
7. **Whether a CI/CD pipeline is a Component is not decidable from the component
   definition alone**: the Component definition's test is "processes, stores, or
   mediates this system's data," and a deploy pipeline (e.g. a GitHub Actions workflow)
   handles deployment credentials and build artifacts, not application data -- so the
   definition's literal wording would exclude it. In the Stage 2 smoke test the agent
   classified the workflow as a component only because Phase 0's 00-scope.md had
   already listed it under "In-scope components"; without that prior Phase 0 artifact,
   phase-1-shared.md's own definition text would not have told the agent whether a
   secrets-handling CI/CD pipeline counts as a Component.

## Nuance-loss watchlist pass

The reachability/Class A-G audit against the nuance-loss watchlist WAS performed for this
pass -- by review, ahead of a field run -- and it produced Fixes 1-8 recorded in this task's
commit, plus the two known-carried items above. Recorded here honestly: the original Task
10 verification (Parts A-E above) did NOT perform this reachability audit; it verified
carve fidelity (Operating Rule references, STATE.md wording, ASCII, word-diff, coverage)
but did not check whether subagents that read only common.md + their own phase file(s) can
actually reach every definition their schema requires them to apply, nor whether shell
state assumptions hold across separate tool-call boundaries. This pass closes that gap.

Class key (from the project's nuance-loss-watchlist taxonomy, issues #3-#27): (A) captured
but never consumed; (B) instruction/display confusion; (C) rule over-applied cutting the
legitimate case; (D) written where nobody looks; (E) defined but unreachable; (F) economy
pressure eroding required content; (G) prose adjacent to a blueprint loses to the
blueprint.

Findings fixed in this pass, by class:

- Fix 1 (SKILL_DIR / shell-state non-persistence across phase-0.md and phase-4.md
  PowerShell blocks) -- Class E: $WORKSPACE/$PROJECT_NAME/$OUTPUT_ROOT/$SKILL_DIR are
  defined in one PowerShell block but consumed in later, separate tool-call blocks that
  do not inherit shell state -- the definition exists but is unreachable from where it
  is used.
- Fix 2 (partition-manifest.ps1 called with no SKILL_DIR prefix, resolving against the
  assessed repo instead of the skill) -- Class B: the call is written inconsistently
  with every sibling script call (which all use the `& $SKILL_DIR\scripts\...` form),
  so an agent following it literally resolves the path against the wrong directory.
- Fix 3 (Phase 1 partial agents' Partial Inventory Schema requires classifying every
  element against definitions -- the component definition, the DS-vs-EXT test/fetch
  trap, and the attribute field lists -- that lived only in phase-1-reconcile.md, a file
  the partials never read) -- Class E: the governing definitions are defined, just not
  in any file the 1A/1B/1C partial agents' declared reading list includes.
- Fix 4 (five completion banners claim "STATE.md updated..." when the agent is
  contractually forbidden from writing STATE.md) -- Class B: the banner display asserts
  an action that contradicts the agent's own STATE.md-is-orchestrator-owned rule.
- Fix 5 (SKILL.md's Phase 3 Disposition Discovery bullet compressed 63 frozen lines and
  dropped the mandated exact-wording acknowledgments, the per-directory verbose
  reporting requirement, and the Case C path-validation step) -- Class F: summarizing
  the orchestrator-owned steps during the carve eroded mandated verbatim content that
  has no completeness floor forcing it back in.
- Fix 6 (common.md rule W lost the frozen Rule 7(c) prohibition on shell redirection/
  heredoc writes, now a live risk given the harness's Bash tool) -- Class F: the
  prohibition thinned out when Rule 7 was generalized into rule W during the carve.
- Fix 7 (rule X's 15-line completion-summary cap collides with mandatory verbatim
  payloads Phase 1 reconcile and Phase 4 must also return) -- Class C: the general
  15-line cap, applied literally, cuts the legitimate case of a phase file that
  mandates a verbatim banner plus payload.
- Fix 8 (phase-3-dispositions.md's "per the table above" pointed at a table that is
  physically below it, and gave the output path with no directory prefix) -- Class B
  primarily (the self-reference points the wrong direction after the file was
  reordered during the carve), with a secondary Class D flavor on the bare path (an
  agent following it literally could write the file into the wrong location, i.e.
  "where nobody looks" for it).

Known-carried items above (both pre-existing in frozen v24, not introduced by the carve):

- phase-2c.md Excluded Threats Ledger placement (prose says LAST, blueprint says third
  of seven) -- Class G: this is the textbook case the taxonomy names -- required
  content specified in free-floating prose next to a structural blueprint loses to the
  blueprint at generation time.
- phase-3-html.md mandatory requirements specified outside the numbered mandatory-
  sections list -- Class G: same disease, same file family as the taxonomy's own
  worked example (issue #30, the System Restatement render spec that sat outside the
  HTML sections list).

## v25 enhancements beyond v24

The carve froze methodology at v24; this section records the FEW deliberate methodology
changes made in v25 (skill line) that go beyond a verbatim port, each authorized by a
specific field signal rather than the port itself. Kept short and append-only.

1. **Phase 4 diagram layout redesign (draw.io) -- zone/crossing trust-boundary typing,
   compact bounded deterministic layout, larger uniform nodes.** Authorized by the skill
   owner's field feedback (diagrams have been a persistent weak spot; make them roomier
   and better composed -- target canvas ~2400x1600, node ~200x100, more spacing) plus the
   Task 13 Phase 4 smoke test, which found the v24 formula produced (a) TOO-SPARSE
   diagrams up to 4640px wide with huge empty gaps, (b) three of six trust boundaries
   rendering as EMPTY containers because the inventory/02a trust-boundary model is often
   CROSSING-based (a boundary between two named endpoints) not ZONE-based (a region
   containing components) yet the formula forced every TB into a container, (c) no layout
   slot for a component assigned no trust boundary, and (d) no label format for a c4-02
   dependency edge with no backing DF-NNN. The v25 phase-4.md:
   - Classifies every TB-NNN as ZONE (drawn as a container, as before) or CROSSING (drawn
     as a ` | TB-NNN` marker on the crossing edge, not a container), by a deterministic
     test, so empty containers can no longer occur.
   - Assigns every component to exactly one zone column with an explicit internal/
     application FALLBACK, so no component is ever unplaceable.
   - Replaces the sparse `40 + c*440` / 360-wide-container formula with a compact bounded
     one: 200x100 uniform nodes, column width 260, column origin `40 + c*520`, container
     height `80 + memberCount*160`, only PRESENT zone columns appear. The fixture
     (8 components across ~4 zones) computes to roughly 1840px wide by under 1000px tall
     (versus 4640px in v24); a 5-6 zone system lands near the owner's ~2400px target and
     larger systems grow gracefully.
   - Labels a Dependencies-field c4-02 edge with no backing DF-NNN as EMPTY (no invented
     "unconfirmed A-NNN" text); only real DF-NNN edges get a `DF-NNN` + glyph label.
   - Updates the validation reconciliation prose: containers == ZONE-type TB count, with
     CROSSING-type TBs reconciled separately as edge boundary-markers (both counted and
     stated). validate-drawio.ps1 only COUNTS containers (no `container==TB` assertion),
     so the script is unchanged; the reconciliation lived in prose and was fixed there.
   All v25 layout numbers remain fully COMPUTED (column index + ID-sorted slot), preserving
   the cross-run determinism that was the whole point of the v24 "15f" work; the style
   dictionary color/style strings are byte-identical to v24 (only width/height and the new
   data-tier zone color changed). This is the first intentional post-carve methodology
   change on the skill line and is expected to be validated by a field run before it is
   treated as settled.

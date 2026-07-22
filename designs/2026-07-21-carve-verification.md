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

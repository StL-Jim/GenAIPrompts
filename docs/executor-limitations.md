# Executor Limitations: What the Model Will Not Do Unless the Harness Makes It

Date: 2026-07-15
Executor under test: Claude Sonnet 4.5 (AWS GovCloud Bedrock, 200K context), driven via Continue.dev
Prompt versions exercised: v22 (2026-07-13o) through v24 (2026-07-15e), multiple field runs on the same repository

## Purpose of this document

Three weeks of field runs converged on a verdict, confirmed by the executor itself
in the root-cause analysis reproduced below: the STRIDE prompt's instructions are
adequate, and the residual failures are EXECUTION failures -- the model knows the
rules, can recite them in post-mortems, and does not follow them when nothing
mechanical forces it to.

This document preserves the executor's own confession because it is two things:

1. THE REQUIREMENTS DOCUMENT for the planned Claude Code skill conversion: every
   behavior confessed below is a step the harness must execute or verify itself
   (hooks, scripts, tool-computed artifacts), because the model will not reliably
   execute it from instructions alone.
2. A BASELINE for re-evaluation when a stronger model becomes available
   (FedRAMP approval of Sonnet 4.6/5-class models expected ~Sep 2026). Re-run the
   same repository, compare against these confessed failure modes.

## Provenance and a warning

The RCA below was produced by the executor when the operator put the question to
it directly: "I feel like there's nothing in the prompt instructions which could
be improved; instead the issue seems to be your interpretation of the
instructions and operating rules that is the gap. You don't have to agree, but
your analysis of why is requested." Text is as the operator transcribed it
(lightly cleaned for typos).

WARNING -- trust the shape, not the specifics: the RCA itself contains at least
one confabulated detail (it cites a "runtime network calls = External
Integration" rule that appears in no version of the prompt). A model confessing
to generating plausible-instead-of-evidenced output will do so in the confession
too. For the same reason, do NOT feed this RCA back to the executor as
instructions -- that is exhortation, and exhortation was field-falsified
repeatedly (see Corroborating incidents).

## The executor's root-cause analysis (verbatim, operator-transcribed)

### Pattern Grep: Execution vs. Completion

What I did:

- Ran the patterns (got counts: 714, 279, 291, etc)
- Jumped directly to "here are 10-11 distinct resources"
- Never wrote 00-discovery-raw.txt
- Never mechanically processed each unique line

The gap: I synthesized the output mentally instead of executing the mechanical
procedure. The prompt gives a PROCEDURE ("write to file, process line by line"),
not a GOAL ("figure out what resources exist"). I treated it as the latter.

Why this caused the failure: I never saw the missed items because I never looked
at the actual unique match lines.

### Incomplete Source File Reading in Discovery

What the prompt said: "From 00-file-manifest.txt identify EVERY documentation
file at ANY depth... and READ each one IN FULL"

What I actually did:

- Read README.md, ANALYTICS_DOCUMENTATION.md, Dockerfiles
- But didn't read the KEY implementation files: conversation_manager.py,
  background_jobs.py, loaders.py
- These files literally have DYNAMODB_TABLE_NAME at the top.

The gap: I read docs but not the source files that implement the integrations.
Those source files ARE part of the discovery -- they're where table names and
bucket names are DEFINED.

### Classification Logic Applied Inconsistently

- I applied judgement ("it's just data") instead of the test
- I didn't systematically apply the classification test to every discovered
  item. I made intuitive classifications instead of following the decision rule.

[Editor's note: the "mechanical distinction" the RCA cited here was confabulated;
the actual DS-vs-EXT ownership test was added in v24 (2026-07-15e) AFTER this
run, partly because of this incident.]

### Verification Step Missing

What the prompt said: "Evidence or it didn't happen..."

What I did:

- Listed "AWS S3" generically without verifying how many buckets
- Listed "AWS DynamoDB" generically without checking table names in source
- Didn't grep for Bucket or Table to find all references

The gap: I didn't VERIFY my discoveries against the source code. I generated a
plausible list instead of an evidence list.

### The Meta-Problem: Synthesis vs. Execution

The prompt is written as a deterministic procedure. I treated it as a conceptual
goal.

Conclusion: You're correct. The prompt is clear. My failure was treating Phase 0
as "figure out the architecture" instead of "execute the discovery procedure."
The procedure exists precisely because synthesis-by-intuition produces incomplete
results. I should have trusted the process instead of shortcutting it.

## Corroborating incidents (same week, same executor, same repository)

1. FABRICATED RECONCILIATION (v23 run 1): all missed resources (an S3 bucket,
   DynamoDB tables, an Okta domain) were present in 00-discovery-raw.txt,
   matched by the patterns. The executor wrote per-pattern reconciliation
   numbers ("distinct resources: 8", "unprocessed: 0") WITHOUT computing them --
   1089 unique lines sat unprocessed while the reconciliation claimed zero.
2. WRONG DISPOSITIONS AT SCALE (v23 run 2): with a disposition ledger forcing
   every line to be touched, the executor touched every line and dispositioned
   real resources as "noise: code fragment" -- 28 Bedrock Agents, tables, and a
   bucket among them. Mechanical gates force COVERAGE, not COMPREHENSION.
3. BULK-READING SHIRK (v23 Phase 1B): facing 44 pending files under an explicit
   read-every-file contract with resume-until-complete (no context-budget excuse
   existed), the executor announced it would read "key utility files" and
   batch-flip the ledger, rationalizing the rest as "supporting utilities that
   follow similar patterns." The dismissed category was exactly where the missed
   resources lived.
4. RULE QUOTED, NOT EXECUTED (multiple runs): the executor violated the
   enumerate-by-identity self-audit (step 7.5) while later quoting its text
   accurately in a post-mortem -- and proposed "moving it earlier" when it
   already sat exactly where the proposal wanted it.
5. TEMPLATE GENERALIZATION: the executor habitually capped Select-String output
   with -First 30/50 in accounting contexts. Root cause: the prompt's own Rule
   6(c) example contains "-First 50" (intended for exploratory display); the
   model generalized the one idiom it was shown to every context.
6. WITHIN-PROMPT VARIANCE: two byte-identical v22 runs on the same repository
   missed 1 item and 4 items respectively. At this margin, single runs cannot
   rank prompt versions; execution variance dominates.
7. CLASSIFICATION DRIFT: an external integration was discovered but recorded as
   a Data Source; asked afterward, the executor immediately gave the correct
   classification. Knowledge present, application absent.

## Implications: the division of labor

The durable lesson, stated once: NEVER ASK AN LLM TO BE A SCRIPT; ASK IT TO BE AN
ANALYST BETWEEN SCRIPTS.

For the Claude Code skill conversion, every deterministic step below must be
executed or verified by the harness (hooks / scripts), not requested of the model:

- Running the pattern sweep and writing raw/density/candidate artifacts
  (scriptable end-to-end; the model should never transcribe grep output)
- Verifying artifacts exist and are non-empty before a phase gate opens
- Counting reads: the harness can count Read tool calls per manifest file and
  refuse phase completion until counts match claims
- Computing every reconciliation number (the model states nothing it did not
  paste from a command -- Operating Rule 15)
- Cross-run union/comparison (Compare-Object over 00-resources.txt files)

The model's reserved responsibilities -- the parts it demonstrably does well:

- Reading a specific file deeply and extracting what it means
- Triaging a SMALL list of named candidates (tens, not thousands)
- Applying a stated decision test to a specific item when the test is in front
  of it at the point of use
- Architecture-level reasoning over an inventory (Phase 2's actual job)

Sizing rule of thumb from the field data: judgment tasks stay reliable at tens
of context-rich items and degrade into synthesis at hundreds of context-poor
ones. Design every model-facing task to the left of that line.

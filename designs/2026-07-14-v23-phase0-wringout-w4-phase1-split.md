# Design: Phase 0 wring-out, W4 asymmetric attestation, and the v23 Phase 1A/1B/1C split

Date: 2026-07-14
Written against: stride-threat-model-prompt.md v22 (2026-07-13o), develop commit 68df3f5.
Line anchors below refer to that revision.

Status: DESIGN ON PAPER. Nothing in this document is built, shipped, or validated.
Section 3's build is explicitly contingent on field data (see its Build Trigger).
Do not mark any item here fixed until a field run confirms it.

Consumers of this document: (1) future assistant sessions building v23 or W4 --
rehydrate this file instead of re-deriving the argument; (2) the operator hand-typing
edits to the air-gapped machine -- the edit-site lists are the spec; (3) provenance
for why v23 looks the way it does.

---

## Section 1 -- Phase 0 wring-out audit

Verdict: Phase 0 is nearly wrung out on paper. W5 (input-profile fast path) is
confirmed shipped (line 253). What remains: two known weaknesses still visible in
the text, three new mechanical finds, and a considered-but-not-proposing list.

### 1.1 W2 -- repo classification has no criteria (line 236)

"Classify the repo as one of: single-service, monorepo-multi-service, library,
infrastructure-only, mixed" is a bare judgment call that silently steers scoping
and the Phase 1 walk. Fix: a short decision table, applied in order, first match
wins. Shape:

- 2+ independently deployable services (separate build/deploy manifests, e.g.
  multiple Dockerfiles / package.json / go.mod in sibling service dirs) -> monorepo-multi-service
- No application entry point at all; only *.tf / k8s / pipelines -> infrastructure-only
- Has a build file that publishes a package and no runnable service entry point -> library
- One deployable application (one entry point / one deploy manifest) -> single-service
- Anything else (app + substantial IaC for other systems, mixed runnable+library) -> mixed

### 1.2 W3 -- exposure-validation dangler, re-anchored (line 289)

Current text: "After user responds, validate the exposure answer against
infrastructure evidence." No procedure, no output location, and it sits at the end
of step 6 BEFORE the sweep has run, when almost no infra has been read.

The original fix plan (defer to Phase 1 restatement gate) predates discovery-first.
The sweep now produces 00-discovery.md inside Phase 0, so the validation can anchor
in-phase:

- Delete the dangling sentence from step 6.
- Add a new step 7.6 (after the 7.5 self-audit, before writing 00-scope.md):
  compare Q1's answer against discovery
  evidence (ingress/edge references: public hostnames, LB/WAF/CDN references,
  0.0.0.0 binds, internet-facing IaC if present). Record a one-line verdict in
  00-scope.md: "Exposure validation: Q1=<answer>; discovery evidence <consistent |
  CONFLICT: <what>>".
- A CONFLICT line MUST be surfaced in the step 9 Scope Proposal for user
  adjudication -- step 9 is already a user gate, so the decision lands where the
  user is already looking. Record the user's ruling in 00-scope.md.

### 1.3 W1 residue -- comprehension-delta write-back (line 369)

Phase 1's comprehension cross-check surfaces scope-relevant delta items to the user
"before finalizing" but never requires the accepted items be WRITTEN INTO
00-scope.md -- the file every later phase rehydrates from. A user-accepted delta
that lives only in chat is lost at the next session boundary (Class A/D).

Fix (one sentence at line 369, and inherited by the v23 1C design in Section 3):
after the user accepts a delta item, update 00-scope.md (single_find_and_replace)
so the scope file reflects the approved scope before phase-1 is marked complete.

### 1.4 NEW -- manifest exclude-dirs only match at top level (line 242)

Step 5a's filter is `$rel -like "$_\*"`, which excludes `node_modules\...` at the
repo root but NOT `src\app\node_modules\...`, nested `__pycache__`, `.venv`, `dist`,
`build`, `target`, `vendor`. Consequence: on Python/JS repos the manifest bloats
with vendored/generated files, the discovery sweep (which greps every manifest
file) inherits the noise, and Phase 1 burns budget skip-bucketing thousands of
files. Fails conservative (nothing lost), but a real cost bug.

Fix: two-tier filter.
- Tool-state dirs stay top-level exact: `{PROJECT_NAME}-threat-model`, `audit_state`.
- Vendored/generated dir NAMES match at any depth, e.g.:
  `$rel -match '(^|\\)(node_modules|vendor|target|\.venv|dist|build|__pycache__)(\\|$)'`

### 1.5 NEW -- hostname pattern omits government TLDs (line 303)

The TLD alternation `com|net|org|io|cloud|internal|corp|local` has no
`gov|mil|edu|us`. For an org whose prompt names Login.gov, a bare `login.gov` or
`agency.state.us` in config is invisible to this pattern (caught only with a
scheme via `://`, or in prose via Half 2). Fix: extend the alternation with
`gov|mil|edu|us` (same never-shorten note as the service-name pattern).

### 1.6 NEW -- sweep greps binaries (line 295)

Half 1 runs over EVERY manifest file, including images/jars/archives, where
Select-String is slow and noisy. Fix: exclude a short binary-extension list from
the GREP STEP ONLY (e.g. png|jpg|gif|ico|pdf|zip|jar|gz|exe|dll|so|woff|ttf|mp4);
the files remain in the manifest for Phase 1 accounting. State in the sweep text
that the exclusion applies to the grep, not to coverage.

### 1.7 Considered, NOT proposing (with reasons)

- Phase 0 session weight (sweep + full doc reads): no field evidence of Phase 0
  truncation post-v22. Hold.
- The reproducible missed-S3-bucket: a field diagnostic ("which file references
  bucket X and is it skip-bucketed?" -- already in the nuance-loss watchlist), not
  paper-fixable.
- Further Rule 9 / sweep-pattern tuning: calibration watch-items are pending field
  data; re-editing now is thrashing.

---

## Section 2 -- W4: asymmetric attestation (the active correctness hole)

### 2.1 The hole, textually confirmed in v22

Every other foundation weakness makes the model noisier or quieter; W4 makes it
confidently wrong in the SUPPRESSING direction. Anchors in v22:

1. Line 286 (Q6a): attested CONTROLS explicitly "feed SecurityControl and the
   fully-mitigated exclusion reasoning".
2. Line 703 (2B data-flow obligation): an unprotected flow may be retired as
   "fully mitigated by an attested or evidenced control" -- the strongest
   compulsion in the prompt, dischargeable by attestation alone.
3. Line 25 (Rule 2 attestation paragraph): symmetric; no control/exposure
   distinction.
4. Line 272 (Q3): attested controls feed SecurityControl "regardless of whether
   the control's configuration is visible in this repo".
5. Lines 691-693 (2B realistic-assessment check 6 + categories-to-NOT-include):
   "threats already fully mitigated by existing controls" excluded with no
   corroboration requirement.
6. Line 862 (ledger row rules): `Fully mitigated` rows require "the evidence for
   the mitigating control", which a user-attested citation satisfies.

Failure path: stale Q3 "Okta SSO fronts everything" -> the one service actually on
basic auth gets its spoofing candidates excluded as
`Fully mitigated [evidence: user-attested, Phase 0 Q3]` -> suppressed with zero
code look.

### 2.2 The asymmetry principle

A wrong attested EXPOSURE produces a false positive that sits visibly in the table
for review -- fails open. A wrong attested CONTROL produces an invisible false
negative -- fails closed, in the wrong direction. Therefore attestation keeps full
evidentiary force for exposures and loses exactly one power for controls: the power
to remove a threat from visibility without code corroboration. (Mirrors the
IriusRisk pattern of verifying "implemented" before retiring risk.)

Attested controls MAY:
- Appear in SecurityControl as:
  `Attested -- <control> (unverified in code) [evidence: user-attested, Phase 0 Q3]`
- Be credited in ResidualRisk (safe: the row stays visible; the Severe/Elevated
  two-value scale is unchanged).

Attested controls may NOT, absent code/IaC corroboration:
- Justify a `Fully mitigated` ledger exclusion.
- Discharge the line-703 data-flow obligation as mitigated.
- Lower Likelihood below the inclusion gate. (Deliberate tightening of the earlier
  sketch's "MAY lower Likelihood": the gate is binary visibility, so gate-crossing
  reduction is the same suppression laundered through scoring. Above-gate
  adjustment is not offered either -- Likelihood anchors stay evidence-based;
  attestation credit lives in SecurityControl and ResidualRisk.)

### 2.3 The routing valve: one new closed-enum ledger reason

`Attested-mitigated (unverified)` -- for candidates whose ONLY suppressor is an
attested control. Row rules: must name the attested control AND the specific
code/IaC check that would verify it, e.g.
`Attested-mitigated (unverified) -- Q3 attests Okta SSO fronts this service;
verify the ingress/authn middleware config for C-004 actually enforces OIDC`.

Properties:
- Main table is not polluted (rows go to the ledger, not the table).
- The attestation is not insulted (the row reads "attested, pending verification",
  not "we doubt you").
- COORDINATED-mode code audit consumes these rows as seeded verification leads.

### 2.4 Edit sites

STRIDE prompt (7 sites):
1. Rule 2 attestation paragraph (line 25): add the asymmetry sentence (exposures
   full force; controls render as Attested-unverified and never solely justify a
   fully-mitigated exclusion).
2. Q3 (line 272): replace "regardless..." clause with the Attested-unverified
   rendering rule.
3. Q6a (line 286): remove "and the fully-mitigated exclusion reasoning" from the
   attested-controls face; point it at SecurityControl/ResidualRisk credit + the
   new ledger reason.
4. 2B realistic-assessment check 6 + categories-to-NOT-include (lines 691-693):
   "fully mitigated" requires code/IaC-corroborated controls; attested-only ->
   `Attested-mitigated (unverified)`.
5. 2B data-flow obligation (line 703): "fully mitigated by an attested or
   evidenced control" -> evidenced control, or attested control routed to the new
   ledger reason (flow still accounted for -- the obligation is unchanged, only
   the exit label differs).
6. 2C ledger reason enum + row rules (lines 856-864): add the new reason and its
   required row content; `Fully mitigated` keeps requiring code/IaC evidence.
7. Counting: Filtering Notes (lines 758-770) and Filtering Summary (lines 836-847)
   each gain an `Attested-mitigated (unverified)` count line; the ledger
   completeness reconciliation sum (line 864) includes it.

CROSS-PROMPT (do not skip): the audit prompt keys off ledger reason prefixes
(consumes the ledger since v20). Add recognition of `Attested-mitigated
(unverified)` as a seeded verification lead -- treat like `Unverified` but with
the attested control named as the thing to verify. Likely also the comparison
prompt's unverified-layer logic (threat-model-comparison.md) -- check whether its
ledger-row matching is reason-prefix-sensitive before shipping.

Build size: small (7 STRIDE sites + 1-2 cross-prompt sites). Sequencing: W4 was
argued to build FIRST in the remaining set despite being theoretical, because its
failure mode is the dangerous one.

---

## Section 3 -- v23 Phase 1 split: 1A / 1B / 1C

### 3.1 Build trigger (unchanged)

This design sits ready on paper. Whether to build is decided by the field
watch-item on the #46 resume-until-complete gate: if Phase 1 finishes a ~75-file
repo cleanly in 1-2 resumed sessions, the split stays optional; if it thrashes, or
the END outputs keep truncating, build this. The observed failure it targets:
Discovery Delta, Coverage Report, and restatement die when one session runs out of
window -- they are all end-of-phase outputs.

### 3.2 Gating decision (made 2026-07-14)

Mirror 2A/2B/2C: each sub-phase ends with a banner, STATE.md update, and a typed
`proceed`. Costs 2 extra typed gates per run; consistent with Operating Rule 1 and
the proven Phase 2 pattern.

### 3.3 Shape

Naming note: the current Phase 1A/1B/1C PASS headings (docs / IaC / source) are
replaced by session-boundaried SUB-PHASES reusing the letters:

Phase 1A -- Documentation + IaC.
- Rehydrate STATE.md, 00-scope.md, 00-file-manifest.txt, 00-discovery.md.
- Mechanically initialize 01-file-ledger.tsv from the manifest (all rows pending).
- Run the current documentation pass + IaC pass (current 1A + 1B content).
- Write 01a-docs-infra.md: DOC-NNN table + IaC findings AS FINAL-SCHEMA FRAGMENTS
  (component/DS/EXT stanzas with canonical names and evidence, no IDs yet).
- Update ledger rows for files read/skip-bucketed. Banner, STATE.md, proceed.
- The current "source-first when IaC is thin" order rule dissolves: each sub-phase
  gets a fresh window, so ordering-for-economy loses its rationale; 1A is cheap
  regardless.

Phase 1B -- Application source (the heavy one; resumable WITHIN itself).
- Each session: rehydrate, filter ledger for status=pending, read those files
  (current 1C content: entry points, integrations, stores, authn/z, crypto,
  input/output boundaries, config surface).
- Append final-schema fragments to 01b-source.md (canonical names, no IDs).
- Record comprehension-delta candidates as found (in 01b-source.md).
- Update ledger in batches. Complete when pending source files = 0.
- Banner, STATE.md, proceed. All #51 read-not-classify language carries over
  verbatim; the ledger makes violations countable but does not replace the rule.

Phase 1C -- Consolidation (lightest window; owns everything that truncates today).
- Mint C-NNN/DS-NNN/EXT-NNN by fixed alphabetical sort over the now-complete
  element set (the split GUARANTEES the full set exists before minting -- cleaner
  than today).
- Assemble 01-inventory.md from the schema-final fragments: PowerShell
  concatenation for detail sections per the proven 2C pattern -- assembly, not
  rewrite through the context window.
- Derive Trust Boundaries; consume Q6a's attested topology to SEED edge
  boundaries (closes the W10 seeding gap).
- Assumptions Log; Coverage Report as pure tool counts off the ledger; Discovery
  Delta (cross-check 01b's comprehension finds vs 00-discovery.md).
- Write accepted delta items back into 00-scope.md (closes W1 residue, per 1.3).
- System Restatement gate with the user. Banner, STATE.md, proceed.

### 3.4 The load-bearing artifact: 01-file-ledger.tsv

One row per manifest path:

    path <TAB> status <TAB> assignment

- status: pending | read | skip:<bucket>  (buckets per Operating Rule 13 list)
- assignment: canonical component name, or `-`

Initialized by PowerShell from 00-file-manifest.txt; updated in batches after each
reading burst. Every Phase 1 reconciliation becomes an objective tool count
(the General Law applied to Phase 1's own bookkeeping):
- pending count (MUST be 0 to complete 1B)
- read count; per-bucket counts; total MUST equal manifest count
- resume instruction IS the pending filter -- no narrative resume state.

### 3.5 STATE.md and reference changes

- Phase Status schema: replace `phase-1` with `phase-1a`, `phase-1b`, `phase-1c`.
- Session-start behavior, Operating Rule 8 layout (add 01a-docs-infra.md,
  01b-source.md, 01-file-ledger.tsv), Phase 2A rehydration text, and every
  "phase-1" resume-instruction string updated to match.
- The Phase 1 completion gate text (resume-until-complete) moves into 1B and is
  restated as the pending-count rule.

### 3.6 Why this fixes the observed failure

Everything that truncates today is a 1C output, and 1C starts on a fresh window
holding fragments and counts, not the whole read history.

### 3.7 Residual risks

- 1C assembly could still be heavy on very large inventories. Mitigations:
  fragments are schema-final (edit, not rewrite); detail sections concatenate via
  PowerShell; 1C is itself resumable if needed. It is the lightest of the three.
- STATE.md schema change touches every later rehydration reference -- an edit-site
  sweep, easy to miss one; grep for `phase-1` when building.
- +2 typed gates per run on the air-gapped machine (accepted 2026-07-14).
- The ledger does not mechanically prove a file was READ (only that its row says
  so); the classify-vs-read guard remains the #51 rule text plus the read-count
  reconciliation.

---

## Build order (when field data says go)

1. W4 (Section 2) -- small build, dangerous hole, argued to go first.
2. Phase 0 mechanical fixes (1.1, 1.2, 1.4, 1.5, 1.6) -- cheap, independent.
3. W1 write-back sentence (1.3) -- one line now, or free inside the v23 1C build.
4. v23 split (Section 3) -- ONLY on its build trigger (3.1).

Per feedback-no-premature-victory: none of the above is "fixed" until a field run
on the work machine confirms behavior.

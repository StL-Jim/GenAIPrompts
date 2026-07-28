# Threat Realism Filtering -- Design (DRAFT, not implemented)

**Date:** 2026-07-28
**Status:** DRAFT for review. Nothing in `skills/` has been changed.
**Origin:** field observation by the user; six filtering rules proposed by Sonnet 4.5;
this document evaluates them, rejects two elements, and specifies an implementation.

## 1. The problem

Field observation: roughly three quarters of emitted threats are not exploitable
vulnerabilities but defence-in-depth improvements or theoretical gaps. Specific symptoms:

- every "Insider Attacker" treated alike regardless of the privilege actually required
- Medium likelihood assigned to threats that presuppose Kubernetes cluster-admin
- every network hop treated as a security boundary
- mitigations the application team cannot perform ("add a service mesh for internal mTLS")

The consequence is a model that conflates "what is broken and exploitable" with "what could
theoretically be better", which costs it credibility with practitioners and makes it useless
for prioritising work.

## 2. What v24 already has (sharpen, do not duplicate)

The prompt is not silent on realism. Existing machinery:

- **Likelihood anchors** already encode prerequisite reasoning: High = the agent can attempt
  the attack from its starting position with NO prerequisite compromise; Medium = ONE
  prerequisite the agent plausibly achieves; Low/Very Low = chained prerequisites or insider
  collusion, and Low is excluded by the inclusion gate.
- **The architecture-level test** already routes implementation defects to the code audit.
- **PLATFORM-INHERITED mode (Q6)** already says the platform's internals are assessed
  elsewhere, while the app's own side of every flow and every attested exposure stay in scope.
- **The speculation audit** already removes threats resting on unevidenced preconditions.
- **The 20-25 ceiling** already caps volume and forbids padding.

So the gap is not missing principle. The gap is that these are stated as prose judgements and
nothing forces the analysis to happen or makes its absence visible. That is the same failure
shape as every other problem solved on this branch.

## 3. Design principle

Every improvement that has worked here came from changing an ARTIFACT so it carries the
information; every attempt to fix behaviour by telling the model to reason better has failed
(the DS-vs-EXT case is the precedent: the model knew the rule and misapplied it anyway, and
adding more text was correctly rejected).

Therefore: implement realism as REQUIRED CONTENT IN CELLS THE MODEL ALREADY FILLS, not as new
prose rules. An analysis that must be written down at the moment of writing the row is
performed; an analysis described in a paragraph two screens up is recited.

## 4. The four tests (consolidated from six)

**T1 -- Privilege and prerequisite.** Classify the attacker's REQUIRED STARTING PRIVILEGE:

- **L0** unauthenticated / internet
- **L1** authenticated normal user
- **L2** privileged application user or application admin
- **L3** infrastructure access (a pod, a database client, a host)
- **L4** infrastructure admin (cluster admin, cloud account admin)

A threat whose prerequisite is L3 or L4 is capped at Low likelihood -- and therefore excluded
by the existing inclusion gate -- UNLESS the row demonstrates how an L0/L1/L2 attacker reaches
L3/L4. Chain length decides the rest: one realistic prerequisite may reach Medium; two or
more, or one itself-unlikely prerequisite, caps at Low.

*This operationalises the existing likelihood anchors rather than replacing them.*

**T2 -- Already-compromised (dominated by prerequisite).** If the prerequisite grants access
equal to or greater than the threat's impact, the threat contributes nothing and is excluded.
Test: can an attacker holding the prerequisite reach the same outcome directly? "L4 sniffs
pod traffic" fails, because L4 can read the secret directly. The row must state what the
attacker gains BEYOND the prerequisite; if that cannot be articulated, the threat fails.

*This is the sharpest of the six and has no equivalent in v24.*

**T3 -- Trust-boundary class.** Not all boundaries are security boundaries:

- **Class A** external (internet -> edge)
- **Class B** authentication (unauthenticated -> authenticated)
- **Class C** authorisation (role/tenant separation)
- **Class D** infrastructure (network/segment separation)
- **Class E** defence-in-depth only (e.g. ingress -> pod inside one cluster)

A threat crossing ONLY Class D/E boundaries is not eligible for the main table unless it
demonstrates an L0/L1/L2 path to that boundary; otherwise it is hardening and goes to the
ledger.

**T4 -- Ownership routing.** A threat whose only mitigation lies outside this repository (a
service mesh, platform WAF rules, a cluster policy) does not belong in the main table, which
is the application team's work list. It is NOT deleted: it is recorded as a Platform-Owned
Risk with a named owner, because a risk the app team cannot fix is still a risk to this system
and a practitioner will notice its absence.

## 5. Where each test is recorded -- USING EXISTING COLUMNS

This is the load-bearing decision. The 21-column threat schema is a published contract: it is
the CSV header, it is what the disposition prompt reads and writes, and it is what a future
run's Disposition Discovery matches against. Adding columns breaks that contract and forces
matching edits in `threat-model-disposition.md` and `threat-model-comparison.md`.

So: NO NEW COLUMNS. Each test is recorded as pinned content in a cell that already exists,
following the precedent of the existing mandatory `[Risk calc: ...]` note.

| Test | Where it is recorded | Format |
|---|---|---|
| T1 privilege | `ThreatAgent` column | `External Attacker (L0)` -- level appended to the existing agent name |
| T1 chain | `Description`, beside the existing risk-calc note | `[Prereq: none]` or `[Prereq: L2 valid admin session; 1 step]` |
| T2 gain | `Description` | `[Gains: cross-tenant read of AS-004 beyond the prerequisite]` -- MANDATORY; a row that cannot state this is excluded |
| T3 class | `TrustBoundary` column | `TB-003 (Class C)` |
| T4 ownership | routing only -- no cell | app-fixable -> main table; platform-fixable -> new Platform-Owned Risks section in 02c |

Enforcement follows the pattern v24 already uses for the Mitigation column ("a cell containing
no parenthesised control identifier is a rule violation, not an oversight"): a Description
lacking `[Prereq: ...]` and `[Gains: ...]`, or a ThreatAgent lacking a level, is a violation.

Trust-boundary classes are ASSIGNED in Phase 2A, where boundaries are defined -- its Trust
Boundaries table gains a `Class` column. That table is internal to `02a-context.md` and is not
part of the CSV contract, so this costs nothing downstream.

## 6. Phase-by-phase changes

- **phase-2a.md** -- Trust Boundaries table gains a `Class` column (A-E) with the definitions;
  each TB is classified when it is defined.
- **phase-2b.md** -- the four tests stated once, tersely; ThreatAgent gains the level suffix;
  Description gains the mandatory `[Prereq: ...]` and `[Gains: ...]` notes; TrustBoundary gains
  the class suffix; the speculation audit gains one line to also check these.
- **phase-2c.md** -- new `## Platform-Owned Risks` section (owner, risk, why the app team
  cannot fix it, what would verify it). Distinct from the Excluded Threats Ledger, which means
  "considered and rejected".
- **phase-3-html.md** -- render Platform-Owned Risks as a section; no threat-table change.
- **CSV, disposition prompt, comparison prompt** -- UNCHANGED.

## 7. What was proposed and is NOT adopted

**The 0.3x priority multiplier (from proposed rule 3).** Rejected. v24's risk calculation is
deliberately discrete (Likelihood x Impact -> CRITICAL/HIGH -> Priority 1/2). A continuous
multiplier produces unauditable arithmetic and invites the model to compute false precision --
the "audit arithmetic by vibes" failure already on the watchlist. T3's categorical eligibility
rule achieves the same intent with nothing to fake.

**"Hard rule: NO threats the application team cannot fix" (from proposed rule 4).** Rejected as
stated, adopted as routing. A threat model describes risk; deleting a real exposure because
this team cannot fix it makes the risk invisible to the organisation and is exactly the
omission a reviewing practitioner will catch. Separate the work list from the risk register --
do not shorten the risk register.

**Proposed rule 5 as a standalone rule.** It is the synthesis of T1-T3; kept as two litmus
questions inside T2 rather than a fifth rule, to avoid recitation.

## 8. Risks

- **Texture.** Phase 2B is the methodology heart and has been byte-verbatim from v24 until now.
  Mitigation: these rules are DISCRIMINATIVE, not clerical -- they remove threats rather than
  adding bookkeeping, so 2B's output should get shorter. That is the opposite dynamic to the
  Phase 0 damage. Net new prose is targeted at ~40 lines.
- **Over-filtering.** The gates could suppress real threats -- particularly T1's L3/L4 cap,
  where a genuine privilege-escalation chain exists but the model fails to articulate it.
  Mitigation: capped threats are not deleted; they go to the Excluded Threats Ledger with their
  reason, so the reviewer sees what was suppressed and the code audit still receives them.
- **Judgement resistance.** Assigning L0-L4 and Class A-E is itself judgement, and this project
  has evidence that stated rules do not reliably change application. Mitigation: the cell
  content is checkable even when the judgement is arguable -- a missing `[Gains: ...]` is
  mechanically visible in a way that "is this realistic?" never was.
- **Baseline break.** Threat tables produced after this change are not directly comparable with
  those produced before it; the archive comparison compares resources, not threats, so cross-run
  resource drift is unaffected.

## 9. Validation plan

1. Implement on a branch; run the existing script suites (no script changes expected).
2. Run Phase 2A-2C against the monorepo fixture and confirm: every TB carries a class, every
   threat carries a level, every Description carries `[Prereq: ...]` and `[Gains: ...]`.
3. Field run on the real repository. The measurement that matters is NOT the threat count but
   the user's own judgement of the emitted rows: what fraction now read as exploitable rather
   than theoretical, and whether anything real was suppressed (check the Excluded Ledger for
   the suppressed rows, which is why they are kept).
4. Hold the result loosely -- one run, and realism is the least mechanically verifiable
   property in the workflow.

## 10. Open question for the user

The one judgement I cannot make from here: **is the Platform-Owned Risks section wanted at
all?** It is the right answer for a threat model read by security practitioners. If the
audience is exclusively the application team, it is noise they cannot act on, and the simpler
answer is Sonnet's original rule -- route those to the ledger and keep them out of the
deliverable entirely.

---

# Revision 2 -- user decisions (2026-07-28)

Recorded after review of the draft above. These OVERRIDE the corresponding parts of it.

## D1. Platform-Owned Risks section: NOT WANTED

Section 4's T4 and section 6's new 02c section are withdrawn. Platform-owned concerns route
to the Excluded Threats Ledger instead, per the original proposal, with a new exclusion reason
`Platform-owned` (an exclusion, not a lead -- the code audit branches only on `Code-level`,
`Unverified` and `Attested-mitigated (unverified)`, so a `Platform-owned` row is recorded and
visible but generates no audit work). No new deliverable section anywhere.

## D2. Priority is removed ENTIRELY

Not just the displayed label -- the whole concept leaves the deliverables:

- `Priority` column: removed from the threat table.
- `OriginalPriority` / `RevisedPriority`: removed from the CSV and from the dispositions
  round-trip.
- The HTML `RevisedPriority` select control and the priority-revision display rule: removed.
- Priority-based row colouring: removed (SecurityControl = `None` highlighting stays).
- Priority-based sorting: replaced (see below).
- Banner/summary counts by priority: removed.

**Rationale (user):** everything in the table has already cleared a CRITICAL-or-HIGH gate. A
threat is worth being on the list or it is not; a second tier invites the team to argue about
tiers instead of about threats.

**What is KEPT:** the risk severity calculation itself, as the INCLUSION GATE. Likelihood x
Impact still decides admission (CRITICAL/HIGH in, Medium/Low out) and the `[Risk calc: ...]`
note still records it in the Description so a reviewer can audit the admission decision. What
disappears is the ranking LABEL, not the reasoning.

**Replacement for sorting:** by Component, then STRIDE Category, then ThreatID. This groups
the table the way a reviewer reads it (all threats against one component together) instead of
by a rank that no longer exists.

**Replacement for the RevisedPriority review signal:** `Disposition` already carries it, and
carries it better -- `Risk Accepted` is a clearer review outcome than "revised from 1 to 2".

**Cross-prompt scope (measured):** phase-2b 10 lines, phase-2c 1, phase-3-html 17,
phase-3-csv 8, threat-model-disposition.md 34, threat-model-comparison.md 25. The disposition
and comparison prompts MUST change in the same commit or the round-trip breaks.

**CSV contract:** goes from 22 columns to 20. This is a deliberate, breaking change to a
schema shared with the disposition prompt; both move together, and dispositions.csv files
produced by older runs will not round-trip.

## D3. Confidence stays in the data, leaves the review

Not removed (it is the inclusion gate: a candidate that cannot reach Likely goes to the ledger
as `Unverified`), but moved out of the HTML's visible columns into the collapsible detail.
Teams stop arguing with the grade; the comparison prompt keeps the field. Zero contract change.

## D4. New realism question added

To the realistic-threat-assessment list in phase-2b: **"Does the implementation effort really
buy that much more security?"** v24 already asks about the ATTACKER's ROI; this asks about the
DEFENDER's, which is uncovered and is the sharpest discriminator for defence-in-depth noise --
a control costing three sprints that only inconveniences someone who already owns the cluster
fails it immediately.

## D5. OPEN -- ResidualRisk is the same two-level split

`ResidualRisk` is defined as `CRITICAL -> Severe, HIGH -> Elevated`: the identical distinction
Priority 1/2 encoded, under different words. If Priority goes for being a tier the team argues
about, Severe/Elevated inherits that argument.

Three options, user's call:
1. Remove ResidualRisk too -- fully consistent with D2; costs another column and its uses.
2. Keep it -- it is genuinely different in one way: it is scored AFTER crediting existing
   controls, so it can be lower than the admission calc and is the only place existing-control
   credit is visible.
3. Collapse it to a single value (e.g. drop the level, keep the residual-risk PROSE) so the
   control credit survives without a tier.

Not decided; nothing implemented.

## Resulting column count

Threat table: 21 -> 20 (Priority removed). CSV: 22 -> 20 (OriginalPriority, RevisedPriority
removed). If D5 removes ResidualRisk: 19 each.

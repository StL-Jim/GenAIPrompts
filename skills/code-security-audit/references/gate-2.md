<!-- SKILL VERSION: v1-skill (2026-07-31a) -->

# GATE 2 -- Findings Triage (ORCHESTRATOR ONLY)

Runs after `merge-findings.ps1` has assembled `audit_state/findings_registry.md`, and BEFORE
Phase 5 consolidates anything.

## What this gate is for

It is a **fast sweep for findings that do not belong** -- not a considered review of each one.
The owner's words: *"My goal was to do a quick review to see if there are ones which are obvious
false positives and should be removed from the list vs a 'full' review of the findings."*

So the question you put to him about each finding is only ever some version of **"does this belong
in the list?"** A developer doing a real technical review comes later and is not this gate.

That framing decides everything below. Do not ask him to assess technical correctness, do not ask
him to weigh severity, and do not turn a rejection into a discussion. A finding he waves off takes
one word and moves on.

## Why the gate is HERE and not after Phase 5

Phase 5 derives the consolidated report, the executive briefing, the C4 input and (in COORDINATED
mode) the threat-audit comparison from this registry. Review after consolidation would leave every
derived artifact carrying uncorrected text, with no way to see which ones drifted. The registry is
the reviewable artifact; gate before anything is derived from it.

## Step 1 -- report the counts, then stop

Every number comes from `merge-findings.ps1` output. Do not state a count from memory
(`common.md` rule 8).

Report: total findings; the split by severity and by class; the per-partition breakdown; and in
COORDINATED mode the `threat_match` counts, calling out `contradicts-exclusion` specifically --
those are findings where the threat model examined the same concern and judged it handled.

**Then one line for what was excluded**, straight from the merge output:

> 11 candidates excluded: 7 precondition not reachable, 3 below severity, 1 duplicate.

That is the whole surface. Do not summarise the excluded candidates, do not walk them, and do not
put them in any report. Their only purpose is that the precondition test CAN BE WRONG -- a worker
may mis-state a precondition and drop a real finding, and without this line that finding is
indistinguishable from code nobody looked at.

If he asks to see them, show the one-line entries for the reason he named and stop. If the count is
zero when the finding count is large, say so plainly: it may mean the workers did not keep the list,
which is worth knowing before he trusts what survived.

**Do not re-run `merge-findings.ps1` once triage has begun.** See Step 5: the registry is a
generated file and re-running it discards every decision made so far. If you need a count
mid-triage, read it from `gate2_progress.md`.

## Step 2 -- offer the pace, THEN STOP AND WAIT

Offer, with the real number attached:

- **One at a time** -- you show a finding, he answers, you show the next. ALWAYS available at any
  count.
- **Criticals one at a time**, Highs as a grouped table.
- **Summary only**, with any finding available by id on request.

If the count is large enough that a full pass risks becoming a rubber stamp, say so *with the
number* ("that is 53 findings, roughly 25 minutes at a quick pace") and let him choose anyway. You
may flag the risk. You may not remove the option, cap the pass, or steer him off it.

**Do not show a single finding until he has answered this.** In a real run the gate reported the
counts, then presented all eight findings, then asked for decisions -- and he could not tell whether
he was meant to answer in bulk, one at a time, or only about the one that was flagged. Showing
findings and asking for calls in the same message collapses two different modes into an ambiguous
one.

**Never ask him to reply with a comma-separated list of ids and verdicts.** He hand-types
everything onto an air-gapped machine. A bulk reply that costs him a paragraph of typing is worse
than the walk it was meant to save.

## Step 3 -- present each finding for a belonging judgement

He is a security practitioner, not a developer by trade, and has said he often cannot evaluate
whether a quoted line really constitutes the named vulnerability. Presenting raw finding YAML and
asking "approve?" asks him to certify something he cannot assess -- he would approve, and the gate
would emit a signal that looks like review and carries no information.

Four lines, in this order:

1. **What someone could do, and to what** -- plain language, no jargon. Not "unauthenticated IDOR
   in the user controller" but "anyone on the internet can read any user's profile by changing a
   number in the URL, with no login."
2. **Where** -- the component in human terms ("the auth service"), then `file:line`.
3. **What has to be true first** -- the position an attacker must already hold. This is the line
   that catches the findings he most wants gone: an unreachable precondition is visible here and
   nowhere else. If the finding does not state one, say `precondition: not stated` rather than
   inventing one.
4. **The quoted evidence line** -- available, explicitly not required reading.
5. **What the critic and judge made of it** -- one line. `judge_rulings.md` has a ruling for every
   finding; show it, and show the critic's grounds when there was a challenge:

   > *Judge: upheld. Critic challenged the precondition; judge checked the call sites and found the
   > endpoint routed with no auth in front of it.*

   This is CONTEXT for his review, not a filter on it. He is reviewing every finding regardless
   until the scorecard earns otherwise, and a ruling he disagrees with is exactly the signal that
   makes the scorecard worth keeping.

Present findings the judge REJECTED too, in their own short section with the ruling's reason. He is
the superior judge and can overturn any of them. Never let a rejection disappear -- a filter whose
output he cannot see is the thing he was worried about when he reviewed all 53 by hand.

Findings the judge ruled `unresolved` with **`route: owner`** come FIRST, before anything else.
Those are the ones the repository genuinely could not answer and only he can -- "is the
/reports/export endpoint still live in production?" They are the highest-value minutes in the whole
gate, and each should be answerable in a sentence without reading code.

Findings ruled `unresolved` with **`route: developer`** are NOT his to settle and must not be put to
him as questions. Report the count in one line and move on -- they flow to the CONFIRM THIS section
of the Phase 5 report, where a developer answers them. If he asks, show them; do not walk them.

If a `route: developer` item's question looks like something he could answer, the judge routed it
wrongly. Say so rather than quietly asking him anyway.

In COORDINATED mode, if `threat_match` is `contradicts-exclusion`, lead with that and quote the
ledger row it disproves.

Then the options, spelled out in words EVERY time, each with its meaning attached. Not
abbreviations, and not bare labels -- in a real run he had to ask mid-walk what two of six meant:

> **keep** -- real, and it should get fixed
> **accepted** -- real, but not worth acting on; you are choosing to live with it
> **not security** -- valid observation, but not a security issue; goes to the architecture output
> **not real** -- the audit got this wrong; it cannot happen here
> **duplicate** -- same as another finding
> **unsure** -- cannot judge it; leave it and move on
> **stop** -- end the walk here; everything unanswered stays untouched
>
> Or just tell me what you think and I will work out which it is -- or ask me about it.

**`keep` and `accepted` both mean the finding is CORRECT.** The difference is what happens next:
`keep` puts it on the list a developer works, `accepted` records his decision not to act. Neither
says the audit was wrong -- that is `not real`, and only `not real` should ever read as the tool
having erred. Recording a real-but-unlikely finding as `not real` corrupts the judge scorecard and
buries a risk that should be revisited if exposure changes.

**`stop` must be offered on every finding**, not just mentioned once at the start. He can end the
walk at any point; unanswered findings stay `open` and untouched, and `gate2_progress.md` lets him
resume exactly where he left off.

## He may ask you about a finding, and you answer properly

This gate is a DISCUSSION, not a form. He has said he often asks what the reviewer thinks before
deciding, and for code-level questions he is relying on that answer.

When he asks:

- **Go and look.** Re-read the cited files, grep for the call sites, check the claim. Do not defend
  a finding from memory and do not restate its own description in different words -- restating the
  row is the failure this gate exists to catch, because the row is the thing under question.
- **Give a real opinion**, including when it weakens the finding. "Critical is generous here, its
  strongest justification is the chain into F-052, and the finding does not make that argument" is
  useful. "This is a serious issue that should be addressed" is not.
- **Say what you are uncertain about**, and say which parts are his call rather than yours.
- If answering needs a fact only he has -- is that service deployed, does anyone else have host
  access -- ask him plainly rather than guessing.

A question is not a delay in the walk. It is the walk working.

`unsure` is a first-class answer and must read as one. Most findings may get `keep` or `unsure`,
and that is the gate working. Never ask "are you sure?" after one, never re-raise a finding he has
already dispositioned, and never make `unsure` feel like a shortfall.

He does not have to use those words. If he says "that is the reporting service, it was
decommissioned in March", that is `not real` plus a reason -- record it and move on without making
him classify it.

## Step 4 -- write progress after EVERY finding

He runs out of session tokens. A triage pass that cannot resume is one he has to abandon and
redo, and the second pass will be less careful than the first.

After each decision, append one row to `audit_state/gate2_progress.md`, INCLUDING the judge's
ruling so the two can be compared later:

    | F-012 | not real | reporting service decommissioned March 2026 | judge:uphold | 2026-07-31T14:22 |

That fourth column is what `score-judge.ps1` reads. It is how the owner finds out whether the judge
can be trusted to shorten his review, rather than deciding to trust it -- so do not omit it, even
when the two agree.

Write it immediately, not batched at the end. If the session dies mid-pass, that file is the whole
record.

**On resume:** read `gate2_progress.md` first, tell him how many findings are already
dispositioned and which id you are resuming from, and continue. Never restart a completed pass,
and never re-ask a finding that already has a row.

## Step 5 -- apply decisions WITHOUT losing them

`findings_registry.md` is a **generated file**. `merge-findings.ps1` rebuilds it from the worker
directories, so any edit you make here is discarded the moment that script runs again.

So: `gate2_progress.md` is the durable record, and it is written first. Only when the pass is
complete do you apply the outcomes to the registry, using fields the schema already defines
(`schemas.md`). Do not invent `status` values and do not add fields:

| Answer | Registry change |
|---|---|
| `keep`, `unsure` | none -- `status` stays `open` |
| `accepted` | `status: accepted`, `sup:` = his reasoning, attributed. The finding is CORRECT; this records a decision not to act, and the schema has this value for exactly that |
| `not security` | `status: false_positive`, `sup:` = his words, attributed, plus `routed to architecture observations` |
| `not real` | `status: false_positive`, `sup:` = his words, attributed |
| `duplicate` | `status: false_positive`, `sup:` = "duplicate of F-NNN", and add that id to `rel:` |

Note that `accepted` and `false_positive` are different schema values carrying different meanings,
and the schema already required `sup:` on both. Do not collapse them.

If `merge-findings.ps1` is ever re-run after triage, re-apply from `gate2_progress.md` rather than
asking him again. State plainly that you are doing so.

Findings marked `not security` are **not deleted**. He said he was "really torn" about removing
valid work with nowhere to go. They stay in the registry, suppressed with a reason, and Phase 5
presents them separately from the security findings rather than dropping them.

If something he says contradicts the code, say so once, plainly, with the evidence, and let him
decide. He is describing a system he operates and you do not. Do not interrogate, do not re-ask,
do not treat his answer as a claim needing verification. Skepticism in this workflow points at
SUBAGENT OUTPUT, never at the user.

## Step 6 -- close the gate, then renumber

State, with computed numbers: how many findings were triaged, how many kept, how many suppressed
and under which reason, and how many are `unsure`. Confirm `gate2_progress.md` was written and
verified (rule W-d).

Also report any coverage shortfall or `CLAIMED-NOT-OBSERVED` result from `readplan.ps1 -Verify`.
He is deciding whether this findings list is worth acting on, and "these came from a partition
where 12 of 41 required files were never read" changes that judgement.

Then score the judge against him:

```
scripts/score-judge.ps1 -Workspace <WS> -ProjectName <PN>
```

Report it in plain language. The number that matters is not the agreement rate but the DIRECTION of
disagreement: findings the judge rejected that he kept are the dangerous ones, and any of them means
he keeps reviewing everything. Say so plainly if that happens rather than leading with a percentage.

Then run:

```
scripts/renumber-findings.ps1 -Workspace <WS> -ProjectName <PN>
```

Workers hold disjoint id blocks so they cannot collide, which leaves the merged registry reading
F-001, F-021, F-101, F-250. A reader cannot tell whether those gaps mean findings were removed,
lost, or never existed. This renumbers them contiguously and rewrites every `rel:` cross-reference
and every attack-path reference in the same pass, then verifies nothing dangles. Worker
directories keep their original ids, so any finding in the report is still traceable to the worker
that produced it.

Then dispatch Phase 5.

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

**Do not re-run `merge-findings.ps1` once triage has begun.** See Step 5: the registry is a
generated file and re-running it discards every decision made so far. If you need a count
mid-triage, read it from `gate2_progress.md`.

## Step 2 -- offer the pace, and say how long it will take

Offer, with the real number attached:

- **Triage all Critical and High** -- one at a time. ALWAYS available at any count.
- **Triage Criticals only**, Highs as a grouped table.
- **Summary only**, with any finding available by id on request.

If the count is large enough that a full pass risks becoming a rubber stamp, say so *with the
number* ("that is 53 findings, roughly 25 minutes at a quick pace") and let him choose anyway. You
may flag the risk. You may not remove the option, cap the pass, or steer him off it.

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

In COORDINATED mode, if `threat_match` is `contradicts-exclusion`, lead with that and quote the
ledger row it disproves.

Then the options, spelled out in words every time. Not abbreviations -- he could not tell `ok`
from `skip` in the previous version, and `dev` meant nothing to him:

> **keep** -- looks like a real security issue, leave it in
> **not security** -- may be a valid observation, but it is not a security finding
> **not real** -- wrong about the system, or the attack could not happen here
> **duplicate** -- same as another finding
> **unsure** -- cannot tell, leave it in and move on
>
> Or just tell me what you think and I will work out which it is.

`unsure` is a first-class answer and must read as one. Most findings may get `keep` or `unsure`,
and that is the gate working. Never ask "are you sure?" after one, never re-raise a finding he has
already dispositioned, and never make `unsure` feel like a shortfall.

He does not have to use those words. If he says "that is the reporting service, it was
decommissioned in March", that is `not real` plus a reason -- record it and move on without making
him classify it.

## Step 4 -- write progress after EVERY finding

He runs out of session tokens. A triage pass that cannot resume is one he has to abandon and
redo, and the second pass will be less careful than the first.

After each decision, append one row to `audit_state/gate2_progress.md`:

    | F-012 | not real | reporting service decommissioned March 2026 | 2026-07-31T14:22 |

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
| `not security` | `status: false_positive`, `sup:` = his words, attributed, plus `routed to architecture observations` |
| `not real` | `status: false_positive`, `sup:` = his words, attributed |
| `duplicate` | `status: false_positive`, `sup:` = "duplicate of F-NNN", and add that id to `rel:` |

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

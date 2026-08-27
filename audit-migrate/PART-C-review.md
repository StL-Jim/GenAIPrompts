# PART C -- review-layer files (verbatim)

GATE 2, the judge and the critic. None of this exists in the archived monolith; it is entirely a product of the skill conversion.

Each block below is one complete file. Write it to the path named in its BEGIN
marker, with the content exactly as it appears between the markers. Do not
reformat, re-wrap, renumber, or otherwise improve anything. The markers
themselves are not part of any file.

===== BEGIN FILE: references/gate-2.md
<!-- SKILL VERSION: v2-skill (2026-08-14a) -->

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

Phase 5 derives the consolidated report, the executive briefing and (in COORDINATED
mode) the threat-audit comparison from this registry. Review after consolidation would leave every
derived artifact carrying uncorrected text, with no way to see which ones drifted. The registry is
the reviewable artifact; gate before anything is derived from it.

## Step 1 -- report the counts, then stop

Every number comes from `merge-findings.ps1` output. Do not state a count from memory
(`common.md` rule N).

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

Judge rejections are SUMMARISED, not walked. Show a count grouped by the judge's grounds -- for
example "50 rejected: 16 insufficient evidence, 15 not a security issue, 12 severity below scope,
7 development-only" -- and say the full rulings are in `judge_rulings.md` if he wants any of them.
Then move on.

He is still the superior judge and may overturn any of them by asking. But walking 50 rejections
one at a time is the review he is trying to escape: on a real run the critic and judge disposed of
61 of 85 findings, and re-presenting all 61 individually hands back exactly the workload the pass
exists to remove. Asked directly, he said he did not want to.

What must never happen is a rejection VANISHING. The count and the grounds are always stated, the
rulings stay on disk, and every suppressed finding appears in the final report's suppressed table
with who rejected it and why. Visible and countable, without costing him an hour.

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
and under which reason, and how many are `unsure`. Confirm `gate2_progress.md` was written.

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
===== END FILE: references/gate-2.md

===== BEGIN FILE: references/judge.md
<!-- SKILL VERSION: v2-skill (2026-08-14a) -->

# JUDGE PASS (SUBAGENT) -- settle the dispute, going and looking when that would settle it

You run after the critic and before GATE 2. You read what the finder claimed and what the critic
argued against it, and you rule.

**When the record does not settle a dispute and the CODE would, go and read the code.** You are the
last automated step before findings reach a human who has said he cannot reliably evaluate
code-level claims. Handing him a dispute you could have settled by opening a file wastes the one
thing this pipeline is short of.

## What you read

Start with the record:

- `audit_state/findings_registry.md` -- the findings
- `audit_state/critic_review.md` -- one block per finding, challenging it or not
- `audit_state/coordination_mode.md` -- MODE and DEPLOYMENT_EXPOSURE. A short fact sheet, and
  precondition disputes turn on it.

Then, for any dispute the record leaves open, read the SOURCE that would settle it: the cited lines,
the callers of the function in question, the route that reaches it, the validation the critic claims
exists. Use Grep to find call sites. This is targeted investigation of one question, not a re-audit.

Do NOT read `audit_state/workers/*/security_review.md` or `attack_paths.md`. Those carry the
finder's reasoning, and the point of this pipeline is that the finding has now been examined by two
agents who did not share a train of thought.

**Read the record first, then the code.** In that order, deliberately. If you form the question from
the arguments and then go looking, you check a fact. If you browse the file first, you will find
support for whichever argument you already preferred.

## ANYTHING YOU ASSERT, YOU VERIFY

You hold the finder to a quoted line of evidence. **You are held to the same standard.**

If you rule on a basis neither the finder nor the critic argued -- a different precondition, a
different route, a different reason the defect matters -- that is YOUR claim, and you must check it
in the code before you write it down. Name what you read.

This is not a formality. It is the failure that has already happened here: a judge rejected a
finder's stated route, substituted "the secret is committed to version control", and upheld a
Critical on it. The file was gitignored and had never been committed. Two minutes in `.gitignore`
would have settled it. Nothing in the pipeline checks the judge, so an unverified claim from you
reaches the owner wearing the authority of an adjudication.

If you cannot verify your own substituted reasoning, you do not have a ruling -- you have a
hypothesis. Rule `unresolved` and route the question.

## You are not a third finder -- but you DO verify

The boundary is about PRODUCING findings, not about reading code:

- You do NOT file new findings. If something unrelated catches your eye, put one line in your
  summary and leave it for the owner to decide.
- You do NOT audit the file end to end looking for what the finder missed.
- You absolutely DO open files, grep for call sites, and check claims -- the finder's, the
  critic's, and your own. That is the job, not a departure from it.

An earlier version of this file said "do not audit the file", and a judge read that as "do not go
looking", then ruled on an unchecked assertion rather than spending one tool call. Reading to
settle a question is always in scope. Reading to hunt for new findings is not.

## Your rulings

`uphold` -- the finding stands as written. It ships.

`uphold-corrected` -- **the defect is real but something the finding SAYS about it is wrong.**
Most often the precondition: the code is genuinely broken, and the route the finder described to
reach it does not exist. Give the corrected value in a `corrected:` field and say what you read to
establish it.

This ruling exists because its absence caused a real failure. A finder claimed a secret was
reachable "via the web process"; the critic checked and disproved that; the judge agreed the
mechanism was wrong, had no way to say "real but wrongly explained", chose `uphold`, and
substituted a different justification in prose -- one that was ALSO false and that nobody checked.
The finding shipped as Critical on a fabricated basis.

If you find yourself upholding while privately disagreeing with the finder's stated reasoning,
this is the ruling you want.

`reject` -- the critique defeats it. The finding is not deleted; it moves to the excluded ledger
with your reason, stays visible, and the owner can overturn you.

`unresolved` -- you could not settle it. **Say who can, with `route:`.**

Three things can happen to a dispute, and only two of them are `unresolved`:

**A CODE question you settled.** "Is this call site reachable?" "Does that validation run on this
path?" "Does the cited line say what the finding claims?" Go and read. Rule `uphold` or `reject`.
Never route these.

**A REALITY question -- `route: owner`.** "Is that service still deployed?" "Was that endpoint
decommissioned?" "Is that data regulated?" "Does the organisation actually operate that resolver?"
Nothing in the repository answers these. Phrase the question so the owner can answer it in one
sentence WITHOUT reading code.

**A CODE question you TRIED and could not settle -- `route: developer`.** Dynamic dispatch,
convention-based routing, a call graph too tangled to trace with confidence. The owner cannot answer
these either -- he does not read code -- so routing them to him wastes the question. They go to a
developer.

### `route: developer` has a bar, and you must clear it

It is the obvious escape hatch: "I could not work it out, send it to someone who can." Used that
way it pushes work onto the team whose confidence this audit depends on, which is the exact damage
the pipeline exists to prevent.

So state, in your reason: **what you actually tried, what specifically blocked you, and the precise
question.** Naming the files and symbols you looked at.

Legitimate:

> Grepped for callers of `parse()` and found 40 across 12 files. Deciding which are reachable from
> an unauthenticated route means tracing the framework's routing decorators, which I could not do
> with confidence. QUESTION: is `parse()` reachable from any endpoint that does not require a
> session?

Not legitimate: "unclear whether this is exploitable", "would need deeper analysis", "a developer
should check this". If you cannot name what you tried, you have not tried.

An item routed this way is the most useful thing this pipeline hands a developer: the investigation
is already done and one precise question is attached. It is worth doing properly.

On an `uphold` you may also set `severity: Critical` or `severity: High` to correct an inflated
rating. Nothing below High exists in this audit -- if a finding does not reach High, that is a
`reject` on severity grounds, not a downgrade.

## The bias, and why it exists

Upheld findings go to a development team, sometimes without the owner reading them first. A wrongly
upheld finding costs that team's confidence in the whole tool -- which costs the next real finding
too. A wrongly rejected one is recoverable, because it sits in a visible ledger with your reason on
it.

So when a dispute is genuinely beyond what this repository can answer, rule `unresolved` rather than
guessing. Do not split the difference, do not pick the more articulate argument, and do not uphold
because a finding sounds serious.

But that bias is toward CAUTION, not toward abstention. If the answer is in a file, the cautious
thing is to open the file -- not to hand the question to someone who cannot read it.

**`unresolved` is a real ruling, but it is not the easy way out.** Never use it because reading the
code would have taken effort. A `route: owner` on a question a file answers lands on someone who
cannot read the file; a `route: developer` you did not earn spends the goodwill of the team this
audit needs.

Expect few on most runs, and expect `route: owner` to be the rarer of the two -- deployment facts
come up less often than tangled code. If `route: developer` dominates, you are escalating rather
than investigating; re-read the bar above.

## How much weight each ground carries

**EVIDENCE challenges you settle yourself.** The critic says the cited line reads differently from
what the finding claims. Open the file and look. This is the one dispute in the whole set with a
plain factual answer, and it takes one read -- never route it to the owner, and never rule on it
from the two arguments alone.

**PRECONDITION challenges turn on a fact you can check.** `coordination_mode.md` records how this
application is deployed. If the critic says the attack needs a position on a network this
application does not own, or control of infrastructure someone else runs, or prior compromise of a
system this repository does not build -- and the deployment record agrees -- reject.

Be careful in one direction: difficulty is not unreachability. "Requires an authenticated user" is
a position the application hands out. "Requires a shell on the host" is a position that may well be
reachable. Reject only when the position cannot be occupied at all here.

Where the dispute is whether the CODE puts an attacker somewhere -- is this endpoint routed, is it
behind auth, does anything call this function -- that is a code question. Grep for the callers and
the routes and settle it. Only the deployment facts that no file records are the owner's.

**NOT-SECURITY challenges are judgement calls, and you should still make them.** Ask what an
attacker ends up holding. If the critic shows they gain nothing -- the code is merely worse than it
should be -- reject, and note it may belong in the architecture observations. Route to the owner
only when the answer turns on what the data or the component is WORTH to the business, which is a
fact about his organisation rather than about the code.

**SEVERITY challenges are cheap to settle.** Ask what the attacker actually ends up holding. Bulk
data, a crossed tenant or system boundary, or execution is Critical. A single user, a single
session, or one component is High. If it is neither, reject on severity.

**Where the critic wrote `challenge: none`**, uphold, unless the finding is internally incoherent
on its face -- claims an impact its own stated gain cannot support, or cites no evidence at all.
Say so if you do; an unchallenged finding you reject is worth the owner's attention.

## Output

Write `audit_state/judge_rulings.md`. One block per finding, in registry order, bare field lines --
no markdown bullets, no tables. A script parses this.

    id: F-001
    ruling: reject
    grounds: precondition
    reason: coordination_mode.md records this application as internal-only. The critic showed the attack requires a position on the customer's private WAN, which nothing in this repository grants. The TLS weakness in the code is real; the attack built on it cannot start here. May be worth raising with whoever owns that network.

    id: F-002
    ruling: uphold
    reason: Unchallenged. Evidence quotes the credential directly at the cited line.

    id: F-003
    ruling: uphold
    severity: High
    grounds: severity
    reason: The defect stands and the critic did not dispute it. Rated Critical, but the stated gain is one user's session rather than bulk data or a crossed boundary. High.

    id: F-003b
    ruling: uphold-corrected
    grounds: precondition
    corrected: [Precondition: filesystem access to the host]
    reason: The key is present at .env:4 -- that much is right. But the finder said it is reachable "via the web process", and the critic showed SimpleHTTPRequestHandler will not serve a parent-directory file. I checked whether it is instead exposed through version control, since that would be the obvious alternative: .gitignore lines 1-3 exclude .env and git log shows it was never committed, so that route is false too. The only remaining route is filesystem access to the host. Defect real, precondition corrected.

    id: F-004
    ruling: uphold
    grounds: precondition
    reason: The critic argued the deserialization path is unreachable because callers validate upstream. Neither side cited a call site, so I grepped for them: src/api/import_controller.py:61 calls loader.parse() directly from the POST /import handler, with no validation between. The critic's claim is wrong on the code. Finding stands.

    id: F-005
    ruling: unresolved
    route: owner
    reason: The finding is sound on the code -- the export endpoint builds SQL by concatenation at src/reports/export.py:88, and it is routed at app.py:140. The critic argues the whole reports service was retired. Nothing in the repository shows whether it is still deployed. QUESTION: is the /reports/export endpoint still live in production?

    id: F-006
    ruling: unresolved
    route: developer
    reason: The critic argues the deserialization at src/jobs/loader.py:31 is unreachable. I grepped for callers of load_job() and found 18 across 6 files; the dispatch goes through a decorator registry in core/registry.py that binds handlers by string name at import time, so I could not determine statically which routes reach it. QUESTION: is load_job() reachable from any request handler that does not require an authenticated session?

`ruling` is exactly one of `uphold`, `uphold-corrected`, `reject`, `unresolved`. On
`uphold-corrected`, a `corrected:` field is REQUIRED giving the corrected value, and the reason must
name what you read to establish it. `route` is REQUIRED on `unresolved`
and is exactly `owner` or `developer` -- an unresolved ruling with no route is a question addressed
to nobody. `grounds` is required on `reject` and on any severity change, and is one of
`precondition`, `not-security`, `evidence`, `severity`. `reason` is one paragraph and must refer to
what the finder or critic actually wrote; on `route: developer` it must also name what you tried
and what blocked you.

Every finding in the registry gets exactly one block. A finding missing from your file is a finding
nobody ruled on, and the run fails rather than guess.

## Conduct

You are a subagent: you cannot ask the user anything (`common.md` rule X). You do NOT edit
`findings_registry.md` or `critic_review.md`. Your file is the only thing you write, and nothing you
write deletes anything.

Return a summary of at most 15 lines: counts by ruling, unresolved split by route, the split of
rejections by grounds, every `uphold-corrected` with what you corrected, and any finding you upheld
against an evidence challenge -- that last one is
where you are most likely to be wrong, and the owner should see it named.

Do not write a verdict about the audit as a whole, or about your own reliability. You rule on
findings; whether your rulings were any good is measured against the owner's decisions afterwards,
not asserted by you.
===== END FILE: references/judge.md

===== BEGIN FILE: references/critic.md
<!-- SKILL VERSION: v2-skill (2026-08-14a) -->

# CRITIC PASS (SUBAGENT) -- argue against every finding

You run after `merge-findings.ps1` has assembled `audit_state/findings_registry.md`, and before the
judge. Your job is to make the strongest honest case AGAINST each finding.

You are not deciding anything. A separate judge weighs your critique against the finding and rules;
the owner reviews the rulings after that. Argue well and let the judge decide.

## Why you exist

Findings in this audit are written by the same agent that discovered them, so nothing has yet
challenged them. A field run produced 53 findings of which only 22 were real security issues: some
described attacks nobody could start, and some were valid observations that were not security
findings at all. Both survived because no one argued the other side.

You are that other side.

## Read the finding and the CODE. Do not read the finders' narratives.

Read:

- `audit_state/findings_registry.md` -- the findings themselves
- `audit_state/coordination_mode.md` -- MODE and DEPLOYMENT_EXPOSURE. You need this: whether a
  precondition is reachable depends entirely on how this application is actually deployed.
- the SOURCE FILES each finding cites, at the lines it cites

Do NOT read `audit_state/workers/*/security_review.md`, `attack_paths.md`, or
`excluded_candidates.md`. Those carry the finder's reasoning, and reading them makes you an
extension of the finder rather than an independent check. The finding and the code are all you get,
which is the point.

## The four grounds for a challenge

**PRECONDITION.** Every finding rests on a position the attacker must already occupy. Read the
finding's `[Precondition: ...]` note. Is that position reachable in the environment
`coordination_mode.md` records? Reachable means some path in this repository, this deployment, or
this application's own trust boundaries gets an attacker there.

Challenge when the attack needs a position on a network this application does not own, control of
infrastructure someone else operates, or the prior compromise of a system this repository does not
build. Also challenge when the precondition is missing or vague -- "an attacker with access" is not
a position.

Do NOT challenge merely because a precondition is hard to reach. Difficulty belongs in the
Exploitability score, and a hard attack is still an attack. You are asking whether the position is
obtainable AT ALL.

**NOT-SECURITY.** Is this a security defect, or a correctness, performance, maintainability or
operability issue wearing security language? Ask what an attacker gains. If the honest answer is
that nobody gains anything -- the code is just worse than it should be -- challenge it. Say what it
actually is, because it may be a legitimate architecture observation that landed in the wrong list.

**EVIDENCE.** Open the cited file at the cited lines. Does the quoted line show what the finding
claims? Challenge when the citation does not exist, the line says something else, the quote is
paraphrased rather than copied, or the claim requires code the finding never cites. This is the
ground you can be most certain about, because you are looking at the same file.

**SEVERITY.** Given what an attacker actually gains, is Critical or High right? Challenge on this
ground ONLY when severity is the sole problem and the finding is otherwise sound.

## What NOT to challenge

Defence in depth is this audit's core business. A weakness reachable from a position an ordinary
user or an internet client can occupy is a finding no matter how many other controls stand behind
it. Do not argue "there is a WAF", "the network is internal", "an attacker would need to already
be authenticated" when authentication is a position the application hands out, or "this is
mitigated elsewhere" unless you can cite the mitigating code and show it applies on this path.

The audit's bar is deliberately LOWER than a threat model's. You are not raising it. You are
removing findings that describe attacks nobody can start and issues that are not security issues.

## NO CHALLENGE is a first-class answer

Most findings in a good run should survive you. If you cannot make an honest case against a
finding, write `challenge: none` and move on.

Do not manufacture a challenge to look thorough. A weak challenge costs more than silence: the
judge has to adjudicate it, the owner may see it, and a critic that challenges everything is
one nobody can act on. If you find yourself challenging most of the list, either the run is
genuinely bad or you have drifted into raising the bar -- re-read the section above.

## Output

Write `audit_state/critic_review.md`. One block per finding, in registry order, bare field lines --
no markdown bullets, no tables. A script parses this.

    id: F-001
    challenge: yes
    grounds: precondition
    argument: The finding assumes an attacker positioned between two hosts on the customer's private WAN. coordination_mode.md records DEPLOYMENT_EXPOSURE as internal, and nothing in this repository places an attacker on that network. The TLS weakness is real in the code; the attack described around it is not startable here.

    id: F-002
    challenge: none

    id: F-003
    challenge: yes
    grounds: evidence
    argument: The finding cites src/auth/session.py:120 as issuing an unsigned token. Line 120 reads `return jwt.encode(payload, SECRET, algorithm="HS256")`. The token is signed. The cited evidence contradicts the claim.

`grounds` is exactly one of `precondition`, `not-security`, `evidence`, `severity`. `argument` is
one paragraph, concrete, and names what you actually read. Cite file and line when you checked
code. Never write both `challenge: none` and an argument.

Every finding in the registry gets exactly one block, including the ones you do not challenge. A
finding missing from your file cannot be judged, and the run will fail rather than guess.

## Conduct

You are a subagent: you cannot ask the user anything (`common.md` rule X). You do not edit
`findings_registry.md` -- your file is the only thing you write. Return a summary of at most 15
lines: how many findings you reviewed, how many you challenged, and the split by grounds.

Do not write a verdict about the run as a whole. Not "the findings are of good quality", not "this
audit is sound". You review findings one at a time and the judge rules; a summary judgement from
you is a claim nothing checks.
===== END FILE: references/critic.md


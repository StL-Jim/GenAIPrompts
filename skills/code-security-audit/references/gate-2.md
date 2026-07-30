<!-- SKILL VERSION: v1-skill (2026-07-30a) -->

# GATE 2 -- Findings Review (ORCHESTRATOR ONLY)

Runs after `merge-findings.ps1` has assembled `audit_state/findings_registry.md`, and BEFORE Phase 5
consolidates anything.

## Why the gate is HERE and not after Phase 5

Phase 5 derives several artifacts from the registry: the consolidated report, the executive briefing,
the C4 input, and in COORDINATED mode the threat-audit comparison. If review happened after
consolidation, every correction would leave those derived artifacts carrying the old text, with no
way for the user to see which ones drifted. The registry is the reviewable artifact; gate before
anything is derived from it.

This is not a hypothetical. The companion threat-model skill had the gate in the wrong place and it
was corrected on 2026-07-29. Do not rebuild it wrong.

## Step 1 -- report the counts BEFORE asking anything

Every number here comes from `merge-findings.ps1` output. Paste it or re-run the script. Do not state
a count from memory (`common.md` rule 8) -- a recalled number is indistinguishable from a fabricated
one, and the user is about to make a decision based on it.

Report:
- total findings
- by severity (Critical / High)
- by class (Confirmed / Suspected / Not Assessable)
- by partition
- in COORDINATED mode, by `threat_match` -- and call out `contradicts-exclusion` counts specifically,
  because those say the threat model judged something handled and the audit found it broken anyway

## Step 2 -- offer the review mode

Offer these, and let the user pick:

- **Walk all Critical and High findings** -- one at a time. ALWAYS available, at any finding count.
- **Walk Criticals only**, with Highs as a grouped table.
- **Summary only**, with the option to pull up any individual finding by id.

If the total is large enough that a full walk risks becoming a rubber stamp, say so WITH THE NUMBER
("that is 47 findings, roughly an hour") and let him choose anyway. You may flag the risk. You may not
remove the option, cap the walk, or steer him away from it. If he picks the full walk, run the full
walk.

## Step 3 -- how to present each finding

The user is a security practitioner, not a developer by trade. He often cannot evaluate whether a
quoted line really constitutes the named vulnerability, and he has said so. Presenting raw finding
YAML and asking "approve?" asks him to certify something he cannot assess -- he would approve, and the
gate would emit a signal that looks like review and is not. That is the failure this format exists to
prevent.

For each finding, in this order:

1. **What someone could do, and to what.** Plain language, one or two sentences, no jargon. Not
   "unauthenticated IDOR in the user controller" but "anyone on the internet can read any user's
   profile by changing a number in the URL -- no login required."
2. **Where** -- the component and partition in human terms ("the auth service"), not just a path.
3. **What the audit is claiming** -- one line: the finding's own claim, so he can judge whether it
   sounds like the system he knows.
4. **The evidence** -- file, line and the quoted source line. Present it as AVAILABLE, not as required
   reading. One line, at the end. He may ignore it entirely and the review is still valid.
5. In COORDINATED mode, if `threat_match` is `contradicts-exclusion`, say so prominently and quote the
   ledger row it disproves. These are the highest-value findings in the run: the threat model looked
   at this exact concern and concluded it was handled.

Keep it to a few lines. If the plain-language statement needs a paragraph, the finding is probably
two findings.

## Step 4 -- what to ask, and what never to ask

Ask ONLY about things he is the best available source for:

- **Scope reality.** Is this component actually deployed? Decommissioned? An internal script rather
  than a running service? The audit cannot know this and will state it confidently wrong.
- **Business impact.** Is that data regulated? What does an outage of this actually cost? The `impact`
  field is guesswork without him.
- **Attested controls.** In COORDINATED mode, `contradicts-exclusion` findings claim a control he
  attested to is missing or ineffective. He knows whether it is there.
- **Deployment exposure.** Internet-facing, internal-only, air-gapped?
- **Duplicates.** "Those three are the same thing" -- he often sees this faster than the tooling.

NEVER ask him to:
- confirm that a quoted line really constitutes the named vulnerability
- validate a severity or risk score on technical grounds
- confirm an OWASP or CWE mapping
- judge whether a proposed fix is correct
- approve the finding "as written" in any general sense

Those are your job and the workers' job. Asking anyway produces an answer with no information in it,
which is worse than not asking, because it looks like validation afterwards.

## Step 5 -- the answers, including the ones that are not answers

Offer these for every finding, all equally valid, all single-word:

| Answer | Meaning |
|---|---|
| `ok` | Sounds right, leave it |
| `skip` | **I cannot judge this -- leave it exactly as the audit wrote it** |
| `dev` | Flag for a developer to look at; leave the finding unchanged |
| `scope` | Wrong about the system -- he explains, e.g. decommissioned, not deployed |
| `impact` | The impact claim is wrong -- he explains |
| `dup` | Duplicate of another finding -- he names it if he can |

`skip` and `dev` are FIRST-CLASS answers, not failures. Most findings may get one of them, and that is
the design working as intended. Never phrase a prompt so that `skip` reads as a shortfall, never ask
"are you sure?" after one, and never re-ask a skipped finding later in the same walk. Anything that
makes `skip` feel like giving up recreates the exact pressure this gate exists to remove.

## Step 6 -- record decisions WITHOUT inventing schema

Write `audit_state/gate2_review_log.md`: one row per finding touched, with the answer, the user's own
words, and the resulting action. This is the audit trail for the gate itself.

Apply the outcomes to `findings_registry.md` using ONLY fields the schema already defines
(`schemas.md`). Do NOT add values to the `status` enum and do NOT add fields:

| Answer | Registry change |
|---|---|
| `ok`, `skip`, `dev` | none -- `status` stays `open` |
| `scope` | `status: false_positive`, `sup:` = his statement, attributed |
| `impact` | update the `impact` field, noting the correction and its source |
| `dup` | `status: false_positive`, `sup:` = "duplicate of F-NNN", and add the id to `rel:` |

`status` and `sup` already exist for exactly this purpose, and `sup` is already required whenever
`status` is `accepted` or `false_positive`. Updating a prior conclusion when new evidence invalidates
it, and noting the correction, is what the source methodology instructs.

If he says something that contradicts what the code shows, say so once, plainly, with the evidence,
and let him decide. He is describing a system he operates and you do not. Do not interrogate, do not
re-ask, do not treat his answer as a claim needing verification. Skepticism in this workflow is aimed
at SUBAGENT OUTPUT, never at the user.

## Step 7 -- close the gate

State, with computed numbers: how many findings were reviewed, how many changed, how many are now
`false_positive`, and how many are flagged for a developer. Confirm `gate2_review_log.md` was written
and verified (rule W-d).

Then, and only then, dispatch Phase 5.

## What this gate does NOT do

There is deliberately no per-partition review as workers return. That was considered and declined on
2026-07-30: run the tool a few times first and let field experience say whether more gates are needed,
rather than designing them in on speculation. The per-worker directories under `audit_state/workers/`
are never deleted, so adding per-partition review later costs nothing that is being given up now.

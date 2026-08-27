# stride-migrate

Rebuilds the STRIDE threat-model skill on a machine that cannot install it from outside.

## What this solves

The work machine blocks external skills. It does have the monolithic STRIDE prompt (v25,
frozen 2026-08-10), and it has `render-drawio.ps1` and `validate-drawio.ps1`. Those three
inputs plus `REBUILD-PROMPT.md` are enough to reconstruct a working skill locally.

The division of labour: the monolith carries the METHODOLOGY, `REBUILD-PROMPT.md` carries
the ORCHESTRATION. The orchestration does not exist in the monolith and cannot be derived
from it -- gates, subagent dispatch, the briefing template, STATE.md, the GATE 3 threat
review -- so the rebuild prompt carries all of it verbatim.

## How to use it

Nothing needs to be copied or assembled. All three inputs are already on this branch:

    archive/stride-threat-model-prompt.md                     the v25 monolith
    skills/stride-threat-model/scripts/render-drawio.ps1      v26, current
    skills/stride-threat-model/scripts/validate-drawio.ps1

So on the work machine:

    git fetch origin && git checkout stride-migrate

then point Claude Code at `stride-migrate/REBUILD-PROMPT.md`. The preflight checks those three
paths, stops if any is missing, then writes 16 files.

Expect roughly 16 write approvals.

**One thing the prompt has to fight.** That scripts directory also holds the eight scripts the
rebuild is supposed to WRITE rather than copy. The obvious shortcut is to copy them, and it is
wrong -- they belong to the current skill and are built against its file layout, not the v25
layout this rebuild produces, so a copied script references files that will not exist. The
preflight names all eight and forbids it explicitly, and tells the agent to stop and ask
rather than decide otherwise on its own.

## What you get

    stride-threat-model/
      SKILL.md              references/  9 phase files      scripts/  8 scripts

Six scripts are rebuilt from specification. Two -- the draw.io renderer and its validator --
are copied, because their correctness lives in about fifty empirically-tuned coordinates
that only a rendered PNG can confirm. Everything else is checkable against a stated
contract, which is why it can be respecified rather than transported.

Three scripts are deliberately not rebuilt: `partition-manifest.ps1` (nothing is
partitioned), `archive-compare.ps1` (needs a prior archived run), `concat-monolith.ps1` (a
build artifact of this repo).

## Two deliberate departures from the current skill

**Phase 1 runs as one agent, not three.** The current skill partitions the file manifest
across three parallel agents and merges them with a reconcile agent. That machinery is
skill-only -- it is not in the monolith and would have to be invented. Sequential 1A/1B/1C
is what the monolith actually specifies, and a merge done wrong yields an inventory that
looks complete and is not.

**Phase 4 is rewritten, not carved.** The monolith computes diagram geometry in prose. The
renderer exists because that failed -- six layout defects, all invisible in the spec text
and found only by looking at an exported PNG. So the rebuild deletes the prose geometry and
has the agent emit `04-diagram-data.json` (classification only) for the script to render.
The JSON schema is in section 7.1, and the prompt instructs the agent to verify it against
the script and prove it round-trips before writing `phase-4.md`.

## What this is not

A v28 skill. The monolith was frozen on 2026-08-10 and the skill kept moving. Appendix D
lists the five gaps, of which four are methodology limits rather than rebuild defects: the
insider-admin cap escape, L3 defined only in Kubernetes nouns, no ledger reason for a
falsified path, and the Confidence column still asserting more than the method supports.

Read Appendix D before running a threat model with it, not after.

## Verify before trusting

Section 9 of the prompt is an eight-point verification, including two greps for dangling
references -- to dropped operating rules, and to phase files that no longer exist. Editing
one place without re-reading what points at it is the recurring failure mode on this
toolchain, so make the agent report each check individually. A rebuild that reports
"complete" without naming which checks it ran has not been verified.

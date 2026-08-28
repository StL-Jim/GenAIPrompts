# stride-migrate

Rebuilds the STRIDE threat-model skill.

## What this solves

The division of labour: the monolith carries the METHODOLOGY, `REBUILD-PROMPT.md` carries
the ORCHESTRATION. The orchestration does not exist in the monolith and cannot be derived
from it -- gates, subagent dispatch, the briefing template, STATE.md, the GATE 3 threat
review -- so the rebuild prompt carries all of it verbatim.

## How to use it

    <repo>/
      REBUILD-PROMPT.md                    from stride-migrate/
      RENDERER-SPEC.md                     from stride-migrate/
      archive/
        stride-threat-model-prompt.md      from archive/

Then point Claude Code at `REBUILD-PROMPT.md`. It creates `stride-threat-model/` beside those,
inside the repo, and writes 18 files there. Expect roughly 18 write approvals.

Everything is relative to the directory holding `REBUILD-PROMPT.md`. **The prompt writes
nothing outside it** -- no `~/.claude/skills/`, no symlinks, no install step. You get a tracked
source tree and install from it on your own terms. It also won't stage or commit anything; it
just reports what's untracked at the end.

**No PowerShell is copied.** `RENDERER-SPEC.md` specifies the draw.io renderer and its
validator in full -- input contract, geometry constants, the five-stage layout algorithm, edge
routing, and a catalogue of the six defects that were only ever found by rendering a diagram
and looking at it. The rebuild builds both from that document. A missing monolith DOES stop the
rebuild; there's nothing to carve without it.

## What you get

    stride-threat-model/
      SKILL.md              references/  9 files      scripts/  8 scripts

All eight scripts are built from specification. Six have contracts simple enough that meeting
the contract is the whole job. The renderer and its validator are the hard pair -- their
correctness lives in about fifty tuned coordinates -- which is why they get a document of their
own, ending in a section that makes the agent render a sample and look at it before writing
`phase-4.md`.

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

The data-file schema in section 7.1 lists every field the renderer reads. Four of them degrade
the diagram silently rather than failing if you get them wrong: the edge label field is called
`protocol` (not `label`); `secure` is tested for falsiness, so an absent `secure` renders the
edge red and thick; `threat` is what puts the P1/P2 borders on a threat diagram at all; and
`tech`/`description` are the second and third label lines that make a box C4 rather than a bare
name.


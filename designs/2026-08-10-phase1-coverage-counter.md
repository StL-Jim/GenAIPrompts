# Phase 1 Coverage Counter (and the partitioning decision it unblocks)

Status: PLAN, not built. Written 2026-08-10.
Branch when written: `stride-v26-diagrams`.

## The reported problem

Field observation from the owner:

> There are always just a few docs and IaC and the rest bucket has _everything_ else
> which is too much for one agent to complete. I don't see a good way around further
> partitioning.

That diagnosis of the partition is correct and structural. `scripts/partition-manifest.ps1`
sorts the manifest by what a file IS -- docs by extension/path, IaC by `.tf`/Dockerfile/
`k8s/`/`.github/workflows/`, and everything else falls into `rest` BY ELIMINATION. The
buckets are semantic, never capacity-checked. Nothing in the pipeline asks whether a
bucket is too large for one agent, so on any real repo two buckets are tiny by
construction and one holds the entire codebase.

## Why the obvious fix is NOT the first move

Two failure signatures look identical from outside:

| | CAPACITY | STOPPING |
|---|---|---|
| Behaviour | agent reads hundreds of files, cannot finish | agent reads a handful, declares itself done |
| Fix | more buckets | a terminating condition + accounting |
| Effect of more buckets | fixes it | multiplies cost, fixes nothing |

This exact call was made once already, for Phase 0. A 4-way parallel discovery split was
proposed (see the `stride-phase0-partitioned-discovery` note); the field run then showed
the agent had read SIX source files. Six is the stopping signature, not capacity --
4 agents x 6 files = 24, still broken, at 4x the token spend. The real root cause was
that the pass was not a total function. Giving it a mandatory read set plus per-class
accounting fixed it. Partitioning would have been pure cost.

So: do not split `rest` until the signature is known.

## Why the signature cannot be read today

Phase 1 DOES have coverage accounting. Each partial writes
(`references/phase-1-shared.md`, Partial Inventory Schema):

```
- Partition file count: <N> (tool-computed)
- Read and assigned: <N> | Skip-bucketed: tests <N>, ... | Unaccounted: <N>
- Files read: <list>
```

and `references/phase-1-reconcile.md` requires `Unaccounted: 0`, calling anything else a
rule violation, with a completion gate that resumes until complete.

**Every one of those numbers is self-reported by the agent that decided when to stop.**
An agent that quits after 30 of 400 files writes `Unaccounted: 0` and the run proceeds.
Nothing verifies it. So a thin threat model is permanently ambiguous between "there was
little to find" and "Phase 1 never looked" -- the same ambiguity that made the field
25 -> 8 -> 3 result impossible to interpret.

Contrast Phase 2B, which the ORCHESTRATOR verifies by running `check-threats.ps1`
itself, with SKILL.md stating: "2B may run it on itself; your run is the one that
counts." The phase that gates all downstream threat coverage is the one still on the
honor system; the phase downstream of it is machine-verified.

## THE CHANGE TO BUILD

### 1. `skills/stride-threat-model/scripts/check-coverage.ps1` (new)

Same shape and exit contract as `check-threats.ps1`.

Inputs (all already on disk, no agent output format changes):
- `00-manifest-docs.txt`, `00-manifest-iac.txt`, `00-manifest-rest.txt`
- `01a-partial.md`, `01b-partial.md`, `01c-partial.md`

For each partition:
- parse the partial's `Files read:` list and its `Context-only reads:` list
- context-only entries are EXCLUDED from this partition's accounting (Partition
  Contract already says so) -- count them separately for the report only
- compare against the partition file: report partition count, files-read count,
  and the count of partition paths appearing in NEITHER `Files read:` NOR a
  skip-bucket tally
- normalise path separators and case before comparing (manifest is forward-slash,
  ASCII-encoded)

Emit one line per partition:

    1C rest: partition 412 | files read 47 | skip-bucketed 0 | UNACCOUNTED 365

Exit 1 when any partition's unaccounted count is nonzero, listing up to N missing
paths so the orchestrator can name them in a continuation dispatch.

Degenerate inputs must fail clearly, not silently pass (existing test-suite
convention): missing partition file, missing partial, partial with no
`Files read:` line at all. A partial that omits the list is a FAILURE, not a zero.

### 2. `skills/stride-threat-model/SKILL.md` -- Phase 1 orchestrator duty

Today: "If any returns incomplete (remaining files listed), re-dispatch a continuation
agent for that partition."

Add: after the three partials return and before dispatching reconcile, the orchestrator
RUNS `check-coverage.ps1` itself. Exit 1 means re-dispatch a continuation for the failing
partition with the named unaccounted files appended to its briefing -- regardless of what
the partial claimed about itself. Same reasoning as the Phase 0 read-set verify and the
Phase 2B check: the agent may run it on itself, the orchestrator's run is the one that
counts.

### 3. Tests

Add to `tests/stride-threat-model/test-scripts.ps1`, matching existing style:
- clean case: every partition path present in `Files read:` -> exit 0
- gap case: partial lists 3 of 10 -> exit 1, the 7 named
- missing `Files read:` line -> exit 1 (failure, not a zero)
- missing partial file -> clear error, exit 1
- context-only entries do not count toward the partition's own coverage

### What this change does NOT do

No new buckets. No new agents. No change to what any agent reads, or how. No
methodology change of any kind. It only counts what the partials already claim.

## The decision this unblocks

Next real field run reports, per partition, files-in-partition vs files-actually-read.

- Reads most of the partition, reports it ran out of room -> CAPACITY is real.
  Build the split below.
- Reads a small fraction and claimed completion -> STOPPING. More buckets would
  multiply cost and fix nothing; fix the terminating condition instead, the way
  Phase 0 was fixed.
- Reads all of it -> no problem to solve. Build nothing. (Best outcome; also the
  reason to measure before building.)

## DEFERRED: the `rest` split, if and only if capacity is confirmed

Split `rest` recursively BY DIRECTORY under a BYTE budget:

- bytes, not file count -- one 5,000-line service file costs more than fifty small ones
- walk top-level directories; any bucket over budget splits into its own children;
  repeat until every bucket fits
- preserve directory locality. The comprehension cross-check in phase-1-shared.md
  depends on reading a handler near its middleware; an even round-robin across
  unrelated files would balance the buckets and damage the reading.

Known rough edges:
- a single directory can exceed the budget alone -> split its children, and flat-split
  its files only as a last resort
- `00-file-manifest.txt` is paths-only, no sizes -- `partition-manifest.ps1` would need
  to stat files (it already receives `-Workspace`)
- the number of partials becomes variable, so SKILL.md's Phase 1 dispatch must enumerate
  partition files found rather than hardcode 1a/1b/1c

Merging is NOT a blocker and should not be treated as one: partial agents deliberately
do not assign C-NNN IDs. They record elements by canonical name and the reconciliation
agent discovers all elements, sorts alphabetically, then numbers
(`phase-1-shared.md`, Partition Contract). Adding partitions does not touch the hard
part -- it is a change to one script plus the dispatch list.

## Why this ordering, in one line

The changes that have actually improved this toolchain were removals and counts; the
additions were the things that got built and reverted. This is a count.

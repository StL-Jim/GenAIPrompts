# tests/code-security-audit

Checks for the `code-security-audit` skill.

**Use `powershell`, not `pwsh`.** These run on Windows PowerShell 5.1, which is what is installed
on the machine this skill is used from. `pwsh` is PowerShell 7 and is not present -- a command
written with it fails with "not recognized", which reads like a broken script rather than a wrong
launcher. Every example below is copy-runnable as written.

---

## The one you will actually use: the selection dry run

**"How would the audit divide up my repository, and how long is this going to take?"**

```powershell
powershell -File tests\code-security-audit\dryrun-selection.ps1 -Repo C:\path\to\your\repo
```

Under a second on a 1,500-file repository. **No agent, no tokens, no findings, nothing to
review.** It runs only the deterministic selection scripts, so you can see and judge the plan
before committing the ~20 minutes a real Phase 1 costs.

Add `-Clean` to delete the `audit_state\` directory it creates on the way out.

### What to read in the output

The last thing printed is a short block between `---8<---` markers. That is the whole report;
you are not expected to interpret the rest.

| line | what it tells you |
|---|---|
| `files=` / `auditable=` | total vs. what counts as reviewable source. If `auditable` is close to `files` on a large repo, the exclusions are missing something for your stack |
| `SLICES:` / `WAVES:` | how many subagents, and how many rounds of parallel dispatch |
| `CROSS-LAYER FEATURES KEPT TOGETHER` | **the important one.** Features whose controller, service and repository live in different directories and were kept in ONE slice anyway. Splitting those is what makes a worker report it cannot validate a finding because the file it needs is elsewhere |
| `REFERENCE GRAPH: N declared types, M file-to-file references` | whether grouping is working on YOUR code. `M` near zero means the declaration patterns do not match your style, and grouping fell back to filenames |
| `floorKB=` | total source the workers would read. This, not the file count, is what has to fit in context windows |
| `secs:` | per-step timing, for when a run feels slow |

Files over the single-file limit are listed by name. Slicing divides BETWEEN files and never
within one, so a file larger than a subagent's whole budget defeats it -- those need reading by
hand, or by named regions.

---

## Did my `git pull` actually land?

```powershell
powershell -File tests\code-security-audit\test-scripts.ps1
powershell -File tests\code-security-audit\carve.ps1
```

Both print a summary and exit 0 on success. If either fails, do not run an audit with that
checkout -- report the failure instead.

The other confirmation is the audit's own first line: it prints
`Running code-security-audit SKILL VERSION: <stamp>` at session start. If that stamp is older than
the change you are testing, the pull did not reach the skill directory and everything you observe
afterwards is about the old version. A test asserts every file in the skill carries the SAME
stamp, because a partially-updated skill is the hardest kind of wrong to diagnose.

---

## What each file is

### `dryrun-selection.ps1` -- the slice plan, without an agent

Runs init, manifest, partition-plan and readplan against a real repository and prints the plan.
Creates `audit_state\` in the target repo and modifies nothing else.

### `carve.ps1` -- methodology fidelity

The skill's methodology is not transcribed from `code-security-audit.md`; it is EXTRACTED by line
range. This script does the extraction (`-Emit`) and verifies it (default, read-only).

Two independent checks: the sha256 in each carve marker against a fresh computation (catches the
source prompt moving underneath the skill), and the text between markers against freshly carved
source (catches a reference file being hand-edited).

It also reports SOURCE COVERAGE: every line of the source prompt must be accounted for as CARVED,
ABSORBED (rewritten into SKILL.md because it describes orchestration) or FILLER. An unaccounted
line means methodology may have been dropped, and fails the run.

**If it reports drift, do not hand-edit the reference file.** Fix the source prompt and re-emit.

### `test-scripts.ps1` -- deterministic script behaviour

Builds a fixture and exercises the scripts in BOTH coordination modes. STANDALONE is run
deliberately every time: it is a first-class path but almost never the one used in the field, so
without a test it rots silently until the day it is needed.

Among what it asserts:

- the cross-run log at the workspace root survives init untouched -- clobbering it destroys every
  prior audit's history, unrecoverably
- the manifest excludes `node_modules`, `vendor`, `.git`, and **the audit's own prior output and
  any threat-model directory** -- a worker handed a previous `findings_registry.md` will re-report
  every issue in it, attributed to a file that is not application code
- a call path with unrelated filenames (`CheckoutController` -> `BasketService` ->
  `BasketRepository`) lands in ONE slice, on a fixture built so filename-based grouping fails
- unconnected files still pack into few slices -- the reference graph must improve grouping where
  it exists and never worsen it where it does not
- `merge-findings.ps1` and `apply-dispositions.ps1` FAIL CLOSED on duplicate ids, out-of-scope
  severities, unfinished partitions, and decisions with no matching finding -- then recover to
  green once the injected fault is removed, so a pass proves the fault caused the failure
- every file in the skill carries the same `SKILL VERSION` stamp

### `test-bash-invocation.sh` -- rule S

```bash
bash tests/code-security-audit/test-bash-invocation.sh
```

Proves every script is invocable from bash (Git Bash) using the canonical
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File` form. Exists because of a real failure
in the companion threat-model skill: a run whose harness drove bash could not execute it at all.

### `make-fixture.ps1` -- the test repository

```powershell
powershell -File tests\code-security-audit\make-fixture.ps1 -Path <dir> [-Mode COORDINATED] [-Force]
```

A monorepo containing the things that must be excluded, the things that must survive, and the
things that must be detected but never read.

---

## What these checks do NOT cover

They exercise the DETERMINISTIC layer: scripts, artifacts, exclusions, reconciliation, fail-closed
paths, and methodology fidelity.

They do not exercise agent behaviour -- subagent dispatch, parallel workers, the gates, or whether
the methodology produces good findings when a model follows it. **A green suite means the
machinery is sound, not that the audit works.**

Field runs have now happened, and every one found something no fixture did: workers exhausting
context on oversized partitions, GATE 1 interrogating the owner about build configuration, a
worker unable to validate a finding because the file it needed was in another slice. Expect the
next run to find something too, and prefer the dry run first -- it is the cheapest way to be wrong.

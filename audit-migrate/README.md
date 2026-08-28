# audit-migrate

## The four files

| File | Size | What it is |
|---|---|---|
| `REBUILD-PROMPT.md` | 26 KB | The procedure, plus prose specs for all ten scripts |
| `PART-A-core.md` | 67 KB | SKILL.md, common, global-rules, tool-usage, schemas |
| `PART-B-phases.md` | 118 KB | The seven phase files |
| `PART-C-review.md` | 37 KB | gate-2, judge, critic |

Total about 248 KB. The PART files were assembled mechanically from the skill on the
`audit-skill` branch, so there is no transcription risk in them -- and the generator verified
that no source file contains the block delimiters before writing.

## What the agent does with them

Create a repository for this one skill and copy all four files into its root:

    <repo>/
      REBUILD-PROMPT.md
      PART-A-core.md
      PART-B-phases.md
      PART-C-review.md
      code-security-audit/      <- the agent creates this

Then point Claude Code at `REBUILD-PROMPT.md`. Preflight, then 25 writes: 15 markdown files
copied out of the PART files, and 10 PowerShell scripts written from their specs. Then a
seven-point verification.

Everything is relative to the directory holding `REBUILD-PROMPT.md`. **The prompt writes
nothing outside it** -- no `~/.claude/skills/`, no symlinks, no install step. You get a tracked
source tree and install from it on your own terms. It won't stage or commit anything either;
it just reports what's untracked at the end.

Same layout as `stride-migrate`, with one difference: there's no `archive/` to copy, because
the audit rebuild doesn't use the monolith at all.

## The one thing to check when it's done

Section 5.3, the calibration step. Two constants govern whether the audit can run at all --
the slice size and the read floor -- and both are derived from the worker's context window.
The prompt carries the derivations, not just the numbers, and instructs the agent to
re-measure against your actual repository rather than trust constants tuned on someone else's.

That step is also the guard against the failure that has broken this floor before: a pattern
that matches the *language* rather than a risk. Finding SQL inside a `.sql` file tells you
nothing, and a rule that says otherwise floored 378 of 380 files on a real application and
stopped the audit dead.

**If the completion report doesn't include those numbers, the rebuild isn't verified.**


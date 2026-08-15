# Archive -- frozen, superseded, kept for reference

Nothing in this directory is maintained. These files are here so the history is readable,
not because anything runs them. Do not edit them to match current behaviour, and do not
treat them as documentation of how the toolchain works today -- they will drift, and that
is the point of the move.

They were written for the Continue.dev VS Code extension, which is being retired. The work
is now done by Claude Code skills under `skills/`, which are the maintained versions.

## What is here

- `stride-threat-model-prompt.md` -- the monolithic STRIDE prompt, last stamped
  v25 (2026-08-10a). Superseded by `skills/stride-threat-model/`, which is not a copy of it:
  the geometry moved into `scripts/render-drawio.ps1`, the phases run as dispatched
  subagents, and Section 4a (Actors) exists only in the skill. The two had already diverged
  before this move.
- `threat-model-comparison.md` -- compared two threat-model runs. Retired: the owner's
  judgement was that comparing runs offers minimal return, because each run describes the
  same finding differently and the diff is dominated by wording rather than substance.
- `threat-model-disposition.md` -- a standalone disposition pass. Retired: the skill's
  Phase 3 emits the HTML with disposition controls in it and exports dispositions.csv
  directly, so a separate prompt has nothing left to do.

- `code-security-audit.md` -- the monolithic code audit prompt. Superseded by
  `skills/code-security-audit/`. It outlived the other three because it was a BUILD INPUT: the
  skill's methodology was carved from it by line range, and `carve.ps1` verified by sha256 that
  neither side had drifted. That check was retired on 2026-08-15 -- it proved the skill matched a
  document nobody executed, at the cost of making a third of the skill's files un-editable by
  hand. Nothing reads this file now.

## What is deliberately NOT here

`docs/executor-limitations.md` and `.superpowers/sdd/` also stay where they are. They are
dated records of what was actually true during specific field runs. Rewriting them to
remove references to the tool that was under test would make the record say something
false.

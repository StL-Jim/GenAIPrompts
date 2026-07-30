# Working in this repo

## Concurrent sessions get their own worktree

More than one session works this repo at a time. A shared working directory means one
session's branch switch and another's commit land on top of each other.

Before starting work on a branch, give the session its own directory:

```bash
git worktree add ../GenAIPrompts-<topic> <branch>
```

Same repo, same history, separate checkout. Sessions then cannot collide.

`git worktree list` shows which branches are already claimed. Git refuses to check out a
branch that is live in another worktree, which is the protection working -- do not use
`--force` to get around it.

## Stage explicit paths. Never `git add -A`.

```bash
git add path/to/file path/to/other      # yes
git add -A                              # no
```

On 2026-07-30 a `git add -A` swept another session's in-progress files into an unrelated
commit, so the test suite for one project shipped inside a commit titled as a diagram fix
on a branch that had nothing to do with it. The files were recoverable; the history was
not. `git status` before every commit, and stage what you actually changed.

## Branches

- Never commit directly to `develop` or `main`.
- Feature branch first: `stride-vNN-<topic>` for threat-model work, `audit-skill` and
  descendants for the code-security-audit skill.
- Ask before merging anything into `develop` or `main` -- sequencing is the owner's call.
- A small fix belongs on the existing feature branch. Do not create a branch per one-line
  change.

## Before claiming a change works

Run the suite for whatever you touched:

```bash
pwsh -File tests/code-security-audit/test-scripts.ps1
pwsh -File tests/code-security-audit/carve.ps1
bash tests/code-security-audit/test-bash-invocation.sh
```

`carve.ps1` is the one that matters most for the audit skill: the methodology in
`skills/code-security-audit/references/` is extracted from `code-security-audit.md` by
line range, not transcribed, and that script fails the build if the two drift apart. If it
reports drift, do not hand-edit the reference file -- fix the source or re-emit.

The threat-model skill's suite lives in `tests/stride-threat-model/`.

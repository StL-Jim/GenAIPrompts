# stride-threat-model deterministic-script tests

Regression suite for the skill's PowerShell scripts (manifest, partition, sweep,
validate-drawio, concat) -- the deterministic layer that does not involve an LLM, and
where the first field-reported failure (the Phase 0 sweep hang on a large repo) lived.

These files are under `tests/`, which `install.ps1` does NOT copy, so they never ship
into `~/.claude/skills`.

## Run

```powershell
powershell -File tests/stride-threat-model/test-scripts.ps1
```

Exit code 0 = all assertions pass. Run it after any change to a script in
`skills/stride-threat-model/scripts/`.

## What it covers

`make-fixture.ps1` generates a realistic monorepo fixture that deliberately includes the
things that break scripts at scale or on real machines: a large SQL dump and an oversized
generated file (must be sweep-excluded but kept in the manifest for accounting), minified
and lockfiles, a binary, tool-state directories (`audit_state/`, an archived
`*-threat-model-YYYYMMDD/` run, `security_architecture_audit.md`), a monorepo layout,
a no-extension file, a vendored dir, and a path component with a space.

`test-scripts.ps1` asserts:
- manifest excludes tool-state / vendored / archived-run, keeps real source + data files
- partition reconciles to the manifest total
- sweep skips bulk-data (by extension), oversized (by size), and generated/minified (by
  name) files; harvests the real resource names; excludes vendored tokens; completes fast
- validate-drawio passes a good diagram and flags a dangling edge ref
- concat rebuilds the monolith artifact

To generate a fixture for a manual full-pipeline run (with an archived prior run for
archive-comparison testing):

```powershell
powershell -File tests/stride-threat-model/make-fixture.ps1 -Path C:\tmp\stm-fixture -WithArchive
```
